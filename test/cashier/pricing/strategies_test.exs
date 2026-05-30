defmodule Cashier.Pricing.StrategiesTest do
  use ExUnit.Case, async: true

  alias Cashier.Pricing.Strategies
  alias Cashier.Pricing.Strategies.BuyOneGetOneFree

  test "all/0 maps each name to its implementing module" do
    all = Strategies.all()
    assert all[:bogo] == BuyOneGetOneFree
    assert all[:bulk_price_drop] == Cashier.Pricing.Strategies.BulkPriceDrop
    assert all[:fractional_discount] == Cashier.Pricing.Strategies.FractionalDiscount
  end

  test "names/0 returns the strategy atoms" do
    names = Enum.sort(Strategies.names())
    assert names == [:bogo, :bulk_price_drop, :fractional_discount]
  end

  describe "fetch/1" do
    test "returns the module for a known strategy" do
      assert {:ok, BuyOneGetOneFree} = Strategies.fetch(:bogo)
    end

    test "returns :error for an unknown strategy" do
      assert :error = Strategies.fetch(:nope)
    end
  end
end
