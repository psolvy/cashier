defmodule Cashier.Catalog do
  @moduledoc """
  In-memory product catalog backed by a protected, read-concurrent ETS table
  owned by this GenServer. Reads hit ETS directly; writes go through the
  GenServer. Codes are normalised to uppercase on read and write.

      iex> {:ok, _} = Cashier.Catalog.create(%{
      ...>   code: "TEA2",
      ...>   name: "Earl Grey",
      ...>   price: Money.new(250, :GBP)
      ...> })
      iex> Cashier.Catalog.get("tea2")
      {:ok, %Cashier.Catalog.Product{code: "TEA2", name: "Earl Grey", price: Money.new(250, :GBP)}}
  """

  use GenServer

  alias Cashier.Catalog.Product

  @table :cashier_catalog

  @doc "List all products, sorted by `code`."
  @spec list() :: [Product.t()]
  def list do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_code, product} -> product end)
    |> Enum.sort_by(& &1.code)
  end

  @doc "Look up a product by code (case-insensitive)."
  @spec get(String.t()) :: {:ok, Product.t()} | :error
  def get(code) when is_binary(code) do
    case :ets.lookup(@table, normalize(code)) do
      [{_code, %Product{} = product}] -> {:ok, product}
      [] -> :error
    end
  end

  @doc "Create a product. Required attrs: `:code`, `:name`, `:price` (`Money.t()`)."
  @spec create(map()) :: {:ok, Product.t()} | {:error, term()}
  def create(attrs) when is_map(attrs), do: GenServer.call(__MODULE__, {:create, attrs})

  @doc "Update `:name` and/or `:price`. The `:code` is immutable — delete + create to change it."
  @spec update(String.t(), map()) :: {:ok, Product.t()} | {:error, term()}
  def update(code, attrs) when is_binary(code) and is_map(attrs) do
    GenServer.call(__MODULE__, {:update, normalize(code), attrs})
  end

  @doc "Delete a product. Fails with `:referenced_by_rules` if any rule still references the code."
  @spec delete(String.t()) :: :ok | {:error, :not_found | :referenced_by_rules}
  def delete(code) when is_binary(code) do
    GenServer.call(__MODULE__, {:delete, normalize(code)})
  end

  @doc "Wipe the table."
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
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create, attrs}, _from, state) do
    with {:ok, product} <- build(attrs),
         :ok <- ensure_absent(product.code) do
      :ets.insert(@table, {product.code, product})
      emit(:created, product.code)
      {:reply, {:ok, product}, state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:update, code, attrs}, _from, state) do
    with [{^code, existing}] <- :ets.lookup(@table, code),
         {:ok, updated} <- merge(existing, attrs) do
      :ets.insert(@table, {updated.code, updated})
      emit(:updated, updated.code)
      {:reply, {:ok, updated}, state}
    else
      [] -> {:reply, {:error, :not_found}, state}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:delete, code}, _from, state) do
    case :ets.lookup(@table, code) do
      [{^code, _product}] -> {:reply, do_delete(code), state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  defp do_delete(code) do
    if Cashier.Pricing.referenced?(code) do
      {:error, :referenced_by_rules}
    else
      :ets.delete(@table, code)
      emit(:deleted, code)
      :ok
    end
  end

  defp build(%{code: code, name: name, price: %Money{} = price}) when is_binary(code) and is_binary(name) do
    code = normalize(code)

    cond do
      code == "" -> {:error, :code_required}
      String.trim(name) == "" -> {:error, :name_required}
      price.amount < 0 -> {:error, :price_negative}
      true -> {:ok, %Product{code: code, name: String.trim(name), price: price}}
    end
  end

  defp build(_), do: {:error, :invalid_attrs}

  defp merge(%Product{} = existing, attrs) when is_map(attrs) do
    updated = struct(existing, Map.take(attrs, [:name, :price]))

    cond do
      not is_binary(updated.name) or String.trim(updated.name) == "" ->
        {:error, :name_required}

      not match?(%Money{}, updated.price) ->
        {:error, :price_required}

      updated.price.amount < 0 ->
        {:error, :price_negative}

      true ->
        {:ok, %{updated | name: String.trim(updated.name)}}
    end
  end

  defp ensure_absent(code) do
    case :ets.lookup(@table, code) do
      [] -> :ok
      _ -> {:error, :code_taken}
    end
  end

  defp normalize(code) when is_binary(code), do: code |> String.trim() |> String.upcase()

  defp emit(action, code) do
    :telemetry.execute([:cashier, :catalog, action], %{count: 1}, %{code: code})
  end
end
