defmodule Cashier.LoaderTest do
  use ExUnit.Case, async: false

  setup do
    Cashier.Pricing.reset!()
    Cashier.Catalog.reset!()
    :ok
  end

  test "load!/0 populates the brief's 3 products and 3 rules" do
    assert :ok = Cashier.Loader.load!()

    assert ["CF1", "GR1", "SR1"] = Enum.map(Cashier.Catalog.list(), & &1.code)
    rules = Cashier.Pricing.list_rules()
    assert length(rules) == 3
    assert Enum.any?(rules, &(&1.strategy == :bogo and &1.product_code == "GR1"))
    assert Enum.any?(rules, &(&1.strategy == :bulk_price_drop and &1.product_code == "SR1"))
    assert Enum.any?(rules, &(&1.strategy == :fractional_discount and &1.product_code == "CF1"))
  end

  test "load!/0 is idempotent" do
    :ok = Cashier.Loader.load!()
    :ok = Cashier.Loader.load!()

    assert length(Cashier.Catalog.list()) == 3
    assert length(Cashier.Pricing.list_rules()) == 3
  end
end
