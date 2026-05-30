defmodule Cashier.Loader do
  @moduledoc """
  Idempotently seeds `Cashier.Catalog` and `Cashier.Pricing` from
  `Cashier.Initial`.

  Runs once at application boot as a supervised `Task` with
  `restart: :transient`. Safe to call manually from `iex` after admin
  CRUD experiments — products and rules that already exist are skipped:

      iex> Cashier.Loader.load!()
      :ok
  """

  alias Cashier.Catalog
  alias Cashier.Initial
  alias Cashier.Pricing

  require Logger

  @doc "Populate the catalog and pricing stores. Idempotent."
  @spec load!() :: :ok
  def load! do
    Logger.info("Cashier.Loader: seeding initial catalog and rules")
    Enum.each(Initial.products(), &ensure_product/1)
    Enum.each(Initial.rules(), &ensure_rule/1)
    :ok
  end

  defp ensure_product(attrs) do
    case Catalog.get(attrs.code) do
      {:ok, _} ->
        :ok

      :error ->
        {:ok, _} = Catalog.create(attrs)
        :ok
    end
  end

  defp ensure_rule(attrs) do
    if rule_exists?(attrs) do
      :ok
    else
      {:ok, _} = Pricing.create_rule(attrs)
      :ok
    end
  end

  defp rule_exists?(attrs) do
    code = String.upcase(attrs.product_code)

    Enum.any?(Pricing.list_rules(), fn r -> r.product_code == code and r.strategy == attrs.strategy end)
  end
end
