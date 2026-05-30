defmodule Cashier.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Cashier.CheckoutRegistry},
      Cashier.Catalog,
      Cashier.Pricing,
      Supervisor.child_spec(
        {Task, fn -> Cashier.Loader.load!() end},
        id: Cashier.Loader,
        restart: :transient
      ),
      Cashier.Checkout.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Cashier.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
