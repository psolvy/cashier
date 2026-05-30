defmodule Cashier.Pricing.Strategies.BuyOneGetOneFreeTest do
  use ExUnit.Case, async: true

  alias Cashier.Pricing.Rule
  alias Cashier.Pricing.Strategies.BuyOneGetOneFree

  @rule %Rule{id: 1, name: "bogo", product_code: "GR1", strategy: :bogo}
  @price Money.new(311, :GBP)

  describe "line_total/3" do
    test "1 unit: pay 1" do
      assert {:ok, Money.new(311, :GBP)} == BuyOneGetOneFree.line_total(1, @price, @rule)
    end

    test "2 units: pay 1" do
      assert {:ok, Money.new(311, :GBP)} == BuyOneGetOneFree.line_total(2, @price, @rule)
    end

    test "3 units: pay 2" do
      assert {:ok, Money.new(622, :GBP)} == BuyOneGetOneFree.line_total(3, @price, @rule)
    end

    test "4 units: pay 2" do
      assert {:ok, Money.new(622, :GBP)} == BuyOneGetOneFree.line_total(4, @price, @rule)
    end

    test "10 units: pay 5" do
      assert {:ok, Money.new(1555, :GBP)} == BuyOneGetOneFree.line_total(10, @price, @rule)
    end
  end

  describe "validate/1" do
    test "accepts an empty rule" do
      assert :ok == BuyOneGetOneFree.validate(@rule)
    end

    test "rejects a rule with new_price" do
      assert {:error, :new_price_not_allowed} ==
               BuyOneGetOneFree.validate(%{@rule | new_price: Money.new(0, :GBP)})
    end

    test "rejects a rule with opts" do
      assert {:error, :opts_not_allowed} ==
               BuyOneGetOneFree.validate(%{@rule | opts: %{anything: 1}})
    end
  end

  test "opts_schema/0 returns an empty list" do
    assert [] == BuyOneGetOneFree.opts_schema()
  end
end
