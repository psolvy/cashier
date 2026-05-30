defmodule Cashier.Checkout.Server do
  @moduledoc """
  A single checkout session. One GenServer per active session, started
  under `Cashier.Checkout.Supervisor` and discoverable through
  `Cashier.CheckoutRegistry`.

  Pricing reads pull live data from `Cashier.Catalog` and `Cashier.Pricing`
  on every `:total` call, so admin rule edits affect the next total. Idle
  measurement uses `System.monotonic_time/1` to stay immune to wall-clock
  adjustments.
  """

  use GenServer, restart: :temporary

  alias Cashier.Catalog
  alias Cashier.Pricing
  alias Cashier.Pricing.Calculator

  @default_idle_timeout_ms 30 * 60 * 1000
  @check_interval_ms 60_000

  defmodule State do
    @moduledoc false
    @enforce_keys [:id, :inserted_at, :last_activity_monotonic_ms, :idle_timeout_ms]
    defstruct [:id, :inserted_at, :last_activity_monotonic_ms, :idle_timeout_ms, items: %{}]

    @type t :: %__MODULE__{
            id: String.t(),
            items: %{String.t() => pos_integer()},
            inserted_at: DateTime.t(),
            last_activity_monotonic_ms: integer(),
            idle_timeout_ms: pos_integer()
          }
  end

  @doc false
  @spec start_link({String.t(), keyword()}) :: GenServer.on_start()
  def start_link({id, opts}) when is_binary(id) and is_list(opts) do
    GenServer.start_link(__MODULE__, {id, opts}, name: via(id))
  end

  @impl true
  def init({id, opts}) do
    state = %State{
      id: id,
      inserted_at: DateTime.utc_now(),
      last_activity_monotonic_ms: monotonic_ms(),
      idle_timeout_ms: Keyword.get(opts, :idle_timeout_ms, @default_idle_timeout_ms)
    }

    schedule_idle_check()
    :telemetry.execute([:cashier, :checkout, :started], %{count: 1}, %{id: id})
    {:ok, state}
  end

  @impl true
  def handle_call({:scan, code}, _from, state) do
    normalised = normalize_code(code)

    case Catalog.get(normalised) do
      {:ok, _product} ->
        new_qty = Map.get(state.items, normalised, 0) + 1
        items = Map.put(state.items, normalised, new_qty)

        :telemetry.execute(
          [:cashier, :checkout, :scan],
          %{count: 1, qty: new_qty},
          %{id: state.id, code: normalised}
        )

        {:reply, {:ok, new_qty}, touch(%{state | items: items})}

      :error ->
        {:reply, {:error, :unknown_product}, state}
    end
  end

  def handle_call({:remove, code}, _from, state) do
    normalised = normalize_code(code)

    case Map.get(state.items, normalised) do
      nil ->
        {:reply, {:error, :not_in_basket}, state}

      qty when qty <= 1 ->
        {:reply, :ok, touch(%{state | items: Map.delete(state.items, normalised)})}

      qty ->
        {:reply, :ok, touch(%{state | items: Map.put(state.items, normalised, qty - 1)})}
    end
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, touch(%{state | items: %{}})}
  end

  def handle_call(:items, _from, state) do
    products = snapshot_products(state.items)
    rules = snapshot_rules(state.items)

    case Calculator.line_totals(state.items, products, rules) do
      {:ok, lines} -> {:reply, {:ok, render_lines(lines, products)}, state}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call(:total, _from, state) do
    products = snapshot_products(state.items)
    rules = snapshot_rules(state.items)

    case Calculator.total(state.items, products, rules) do
      {:ok, money} = ok ->
        :telemetry.execute(
          [:cashier, :checkout, :total],
          %{amount: money.amount},
          %{id: state.id, currency: money.currency}
        )

        {:reply, ok, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_info(:idle_check, state) do
    age_ms = monotonic_ms() - state.last_activity_monotonic_ms

    if age_ms >= state.idle_timeout_ms do
      {:stop, :normal, state}
    else
      schedule_idle_check()
      {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    :telemetry.execute(
      [:cashier, :checkout, :stopped],
      %{count: 1},
      %{id: state.id, reason: reason}
    )

    :ok
  end

  defp via(id), do: {:via, Registry, {Cashier.CheckoutRegistry, id}}

  defp touch(%State{} = state), do: %{state | last_activity_monotonic_ms: monotonic_ms()}

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  defp schedule_idle_check do
    Process.send_after(self(), :idle_check, @check_interval_ms)
  end

  defp normalize_code(code) when is_binary(code), do: code |> String.trim() |> String.upcase()

  defp snapshot_products(items) do
    Enum.reduce(items, %{}, &put_product/2)
  end

  defp put_product({code, _qty}, acc) do
    case Catalog.get(code) do
      {:ok, product} -> Map.put(acc, code, product)
      :error -> acc
    end
  end

  defp render_lines(lines, products) do
    lines
    |> Enum.map(&render_line(&1, products))
    |> Enum.sort_by(& &1.code)
  end

  defp render_line({code, qty, line_total}, products) do
    %{code: code, name: products[code].name, qty: qty, line_total: line_total}
  end

  defp snapshot_rules(items) do
    Enum.reduce(items, %{}, fn {code, _qty}, acc ->
      Map.put(acc, code, Pricing.rules_for(code))
    end)
  end
end
