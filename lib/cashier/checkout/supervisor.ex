defmodule Cashier.Checkout.Supervisor do
  @moduledoc """
  `DynamicSupervisor` for `Cashier.Checkout.Server` children. Each session
  is `:temporary` and self-terminates on idle timeout.
  """

  use DynamicSupervisor

  @doc false
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 3, max_seconds: 5)
  end

  @doc "Start a new checkout session under this supervisor."
  @spec start_child(String.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_child(id, opts \\ []) when is_binary(id) and is_list(opts) do
    DynamicSupervisor.start_child(__MODULE__, {Cashier.Checkout.Server, {id, opts}})
  end
end
