defmodule Cashier.Pricing do
  @moduledoc """
  In-memory pricing-rule store backed by a protected, read-concurrent ETS
  table owned by this GenServer.

  Each rule is uniquely identified by `(product_code, strategy)` — admins
  edit the active one rather than stacking duplicates. The store also
  enforces strategy-specific validation by delegating to the strategy
  module's `validate/1` callback.

  Reads (`list_rules/0`, `rules_for/1`, `referenced?/1`) hit ETS directly;
  writes go through the GenServer.

  ## iex example

      iex> {:ok, _} = Cashier.Pricing.create_rule(%{
      ...>   name: "Demo bulk",
      ...>   product_code: "GR1",
      ...>   strategy: :bulk_price_drop,
      ...>   opts: %{min_qty: 2},
      ...>   new_price: Money.new(150, :GBP)
      ...> })
      iex> [%Cashier.Pricing.Rule{strategy: :bulk_price_drop}] = Cashier.Pricing.rules_for("GR1") |> Enum.filter(&(&1.strategy == :bulk_price_drop))
  """

  use GenServer

  alias Cashier.Pricing.Rule
  alias Cashier.Pricing.Strategies

  @table :cashier_pricing_rules

  @doc "All rules, sorted by `priority` desc then `inserted_at` asc."
  @spec list_rules() :: [Rule.t()]
  def list_rules do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, rule} -> rule end)
    |> sort_rules()
  end

  @doc """
  Active rules for the given product code, in evaluation order. The
  `Cashier.Pricing.Calculator` uses the head of this list per code.
  """
  @spec rules_for(String.t()) :: [Rule.t()]
  def rules_for(code) when is_binary(code) do
    code = normalize(code)

    Enum.filter(list_rules(), &(&1.product_code == code and &1.active))
  end

  @doc "Is the product code referenced by any rule (active or not)?"
  @spec referenced?(String.t()) :: boolean()
  def referenced?(code) when is_binary(code) do
    code = normalize(code)

    @table
    |> :ets.tab2list()
    |> Enum.any?(fn {_id, rule} -> rule.product_code == code end)
  end

  @doc """
  Create a pricing rule. The rule's `:strategy` callback module validates
  `opts` and `new_price` before the record lands in the table.

  Required attrs: `:name`, `:product_code`, `:strategy`. Optional: `:opts`,
  `:new_price`, `:active` (default `true`), `:priority` (default `0`).
  """
  @spec create_rule(map()) :: {:ok, Rule.t()} | {:error, term()}
  def create_rule(attrs) when is_map(attrs), do: GenServer.call(__MODULE__, {:create, attrs})

  @doc "Update mutable fields of an existing rule by id."
  @spec update_rule(pos_integer(), map()) :: {:ok, Rule.t()} | {:error, term()}
  def update_rule(id, attrs) when is_integer(id) and is_map(attrs), do: GenServer.call(__MODULE__, {:update, id, attrs})

  @doc "Delete a rule by id."
  @spec delete_rule(pos_integer()) :: :ok | {:error, :not_found}
  def delete_rule(id) when is_integer(id), do: GenServer.call(__MODULE__, {:delete, id})

  @doc "Toggle a rule on."
  @spec activate(pos_integer()) :: {:ok, Rule.t()} | {:error, term()}
  def activate(id), do: update_rule(id, %{active: true})

  @doc "Toggle a rule off; the calculator will skip it."
  @spec deactivate(pos_integer()) :: {:ok, Rule.t()} | {:error, term()}
  def deactivate(id), do: update_rule(id, %{active: false})

  @doc "Wipe the table and reset the id counter."
  @spec reset!() :: :ok
  def reset!, do: GenServer.call(__MODULE__, :reset)

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :protected, :set, read_concurrency: true])
    {:ok, %{next_id: 1}}
  end

  @impl true
  def handle_call({:create, attrs}, _from, state) do
    with {:ok, rule} <- build(attrs, state.next_id),
         :ok <- ensure_product_exists(rule),
         :ok <- validate_rule(rule),
         :ok <- ensure_unique(rule, nil) do
      :ets.insert(@table, {rule.id, rule})
      emit(:created, rule)
      {:reply, {:ok, rule}, %{state | next_id: state.next_id + 1}}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:update, id, attrs}, _from, state) do
    with [{^id, existing}] <- :ets.lookup(@table, id),
         {:ok, updated} <- merge(existing, attrs),
         :ok <- validate_rule(updated),
         :ok <- ensure_unique(updated, id) do
      :ets.insert(@table, {updated.id, updated})
      emit(:updated, updated)
      {:reply, {:ok, updated}, state}
    else
      [] -> {:reply, {:error, :not_found}, state}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:delete, id}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, rule}] ->
        :ets.delete(@table, id)
        emit(:deleted, rule)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, %{state | next_id: 1}}
  end

  defp build(%{name: name, product_code: code, strategy: strategy} = attrs, id)
       when is_binary(name) and is_binary(code) and is_atom(strategy) do
    rule = %Rule{
      id: id,
      name: String.trim(name),
      product_code: normalize(code),
      strategy: strategy,
      opts: Map.get(attrs, :opts, %{}),
      new_price: Map.get(attrs, :new_price),
      active: Map.get(attrs, :active, true),
      priority: Map.get(attrs, :priority, 0),
      inserted_at: DateTime.utc_now()
    }

    cond do
      rule.name == "" -> {:error, :name_required}
      rule.product_code == "" -> {:error, :product_code_required}
      true -> {:ok, rule}
    end
  end

  defp build(_, _), do: {:error, :invalid_attrs}

  defp merge(%Rule{} = existing, attrs) when is_map(attrs) do
    merged = %{
      existing
      | name: trim_or_keep(Map.get(attrs, :name, existing.name)),
        opts: Map.get(attrs, :opts, existing.opts),
        new_price: Map.get(attrs, :new_price, existing.new_price),
        active: Map.get(attrs, :active, existing.active),
        priority: Map.get(attrs, :priority, existing.priority)
    }

    if merged.name == "", do: {:error, :name_required}, else: {:ok, merged}
  end

  defp validate_rule(%Rule{strategy: name} = rule) do
    case Strategies.fetch(name) do
      {:ok, module} -> module.validate(rule)
      :error -> {:error, {:unknown_strategy, name}}
    end
  end

  defp ensure_product_exists(%Rule{product_code: code}) do
    case Cashier.Catalog.get(code) do
      {:ok, _product} -> :ok
      :error -> {:error, {:unknown_product, code}}
    end
  end

  defp ensure_unique(%Rule{product_code: code, strategy: strategy}, except_id) do
    duplicate? =
      @table
      |> :ets.tab2list()
      |> Enum.any?(fn {id, r} ->
        id != except_id and r.product_code == code and r.strategy == strategy
      end)

    if duplicate?, do: {:error, :rule_already_exists}, else: :ok
  end

  defp sort_rules(rules), do: Enum.sort(rules, &compare_rules/2)

  defp compare_rules(a, b) do
    cond do
      a.priority > b.priority -> true
      a.priority < b.priority -> false
      true -> DateTime.compare(a.inserted_at, b.inserted_at) != :gt
    end
  end

  defp normalize(code), do: code |> String.trim() |> String.upcase()

  defp trim_or_keep(value) when is_binary(value), do: String.trim(value)
  defp trim_or_keep(value), do: value

  defp emit(action, %Rule{id: id, product_code: code, strategy: strategy}) do
    :telemetry.execute(
      [:cashier, :pricing, action],
      %{count: 1},
      %{id: id, product_code: code, strategy: strategy}
    )
  end
end
