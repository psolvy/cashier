defmodule Cashier.Initial do
  @moduledoc """
  Canonical seed data per the Kantox brief. Returned as plain maps suitable
  for `Cashier.Catalog.create/1` and `Cashier.Pricing.create_rule/1`.
  """

  @doc "Products from the brief."
  @spec products() :: [map()]
  def products do
    [
      %{code: "GR1", name: "Green tea", price: Money.new(311, :GBP)},
      %{code: "SR1", name: "Strawberries", price: Money.new(500, :GBP)},
      %{code: "CF1", name: "Coffee", price: Money.new(1123, :GBP)}
    ]
  end

  @doc "Pricing rules from the brief."
  @spec rules() :: [map()]
  def rules do
    [
      %{
        name: "CEO BOGO Green Tea",
        product_code: "GR1",
        strategy: :bogo,
        opts: %{},
        new_price: nil
      },
      %{
        name: "COO Bulk Strawberries",
        product_code: "SR1",
        strategy: :bulk_price_drop,
        opts: %{min_qty: 3},
        new_price: Money.new(450, :GBP)
      },
      %{
        name: "CTO Coffee Two-Thirds",
        product_code: "CF1",
        strategy: :fractional_discount,
        opts: %{min_qty: 3, numerator: 2, denominator: 3},
        new_price: nil
      }
    ]
  end
end
