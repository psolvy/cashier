defmodule Cashier.Fixtures do
  @moduledoc """
  Test fixtures for the Kantox brief's products + rules.

  Two flavours:

    * `products_map/0` + `rules_map/0` — plain maps suitable for the
      pure `Cashier.Pricing.Calculator.total/3`.
    * `seed_stores!/0` — resets the live `Cashier.Catalog` and
      `Cashier.Pricing` GenServers, then re-runs `Cashier.Loader.load!/0`
      to populate them with the brief's data.
  """

  alias Cashier.Catalog.Product
  alias Cashier.Pricing.Rule

  @doc "Brief's three products keyed by code."
  @spec products_map() :: %{String.t() => Product.t()}
  def products_map do
    %{
      "GR1" => %Product{code: "GR1", name: "Green tea", price: Money.new(311, :GBP)},
      "SR1" => %Product{code: "SR1", name: "Strawberries", price: Money.new(500, :GBP)},
      "CF1" => %Product{code: "CF1", name: "Coffee", price: Money.new(1123, :GBP)}
    }
  end

  @doc "Brief's three rules keyed by product code (each list pre-sorted)."
  @spec rules_map() :: %{String.t() => [Rule.t()]}
  def rules_map do
    now = DateTime.utc_now()

    %{
      "GR1" => [
        %Rule{
          id: 1,
          name: "CEO BOGO Green Tea",
          product_code: "GR1",
          strategy: :bogo,
          inserted_at: now
        }
      ],
      "SR1" => [
        %Rule{
          id: 2,
          name: "COO Bulk Strawberries",
          product_code: "SR1",
          strategy: :bulk_price_drop,
          opts: %{min_qty: 3},
          new_price: Money.new(450, :GBP),
          inserted_at: now
        }
      ],
      "CF1" => [
        %Rule{
          id: 3,
          name: "CTO Coffee Two-Thirds",
          product_code: "CF1",
          strategy: :fractional_discount,
          opts: %{min_qty: 3, numerator: 2, denominator: 3},
          inserted_at: now
        }
      ]
    }
  end

  @doc "Turn a basket string like `\"GR1,SR1,GR1\"` into `%{code => qty}`."
  @spec basket(String.t()) :: %{String.t() => pos_integer()}
  def basket(string) when is_binary(string) do
    string
    |> String.split(",", trim: true)
    |> Enum.frequencies()
  end

  @doc """
  Reset live state holders and re-seed from `Cashier.Initial`.
  Use as `setup :seed_stores!` in shared-state tests.
  """
  @spec seed_stores!(map()) :: :ok
  def seed_stores!(_context \\ %{}) do
    Cashier.Pricing.reset!()
    Cashier.Catalog.reset!()
    Cashier.Loader.load!()
    :ok
  end
end
