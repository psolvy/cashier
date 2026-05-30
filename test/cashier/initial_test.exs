defmodule Cashier.InitialTest do
  use ExUnit.Case, async: true

  alias Cashier.Initial

  test "products/0 returns exactly the three brief products" do
    codes = Initial.products() |> Enum.map(& &1.code) |> Enum.sort()
    assert codes == ["CF1", "GR1", "SR1"]

    for %{price: %Money{currency: currency}} <- Initial.products() do
      assert currency == :GBP
    end
  end

  test "rules/0 references the same product codes" do
    codes = Initial.rules() |> Enum.map(& &1.product_code) |> Enum.sort()
    assert codes == ["CF1", "GR1", "SR1"]
  end

  test "rules/0 carry their strategy atoms" do
    strategies = Initial.rules() |> Enum.map(& &1.strategy) |> Enum.sort()
    assert strategies == [:bogo, :bulk_price_drop, :fractional_discount]
  end
end
