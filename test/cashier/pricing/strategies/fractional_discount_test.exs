defmodule Cashier.Pricing.Strategies.FractionalDiscountTest do
  use ExUnit.Case, async: true

  alias Cashier.Pricing.Rule
  alias Cashier.Pricing.Strategies.FractionalDiscount

  @rule %Rule{
    id: 1,
    name: "fractional",
    product_code: "CF1",
    strategy: :fractional_discount,
    opts: %{min_qty: 3, numerator: 2, denominator: 3}
  }
  @price Money.new(1123, :GBP)

  describe "line_total/3" do
    test "below threshold uses unit_price" do
      assert {:ok, Money.new(2246, :GBP)} == FractionalDiscount.line_total(2, @price, @rule)
    end

    test "at threshold applies 2/3 multiplier (brief's CF1 case)" do
      assert {:ok, Money.new(2246, :GBP)} == FractionalDiscount.line_total(3, @price, @rule)
    end

    test "above threshold continues to apply multiplier" do
      assert {:ok, Money.new(2994, :GBP)} == FractionalDiscount.line_total(4, @price, @rule)
    end

    test "rounding is toward zero (floor for non-negatives)" do
      assert {:ok, Money.new(3743, :GBP)} == FractionalDiscount.line_total(5, @price, @rule)
    end
  end

  describe "validate/1" do
    test "accepts a well-formed rule" do
      assert :ok == FractionalDiscount.validate(@rule)
    end

    test "rejects denominator <= 0" do
      assert {:error, :denominator_invalid} ==
               FractionalDiscount.validate(%{
                 @rule
                 | opts: %{min_qty: 3, numerator: 2, denominator: 0}
               })
    end

    test "rejects negative numerator" do
      assert {:error, :numerator_invalid} ==
               FractionalDiscount.validate(%{
                 @rule
                 | opts: %{min_qty: 3, numerator: -1, denominator: 3}
               })
    end

    test "rejects min_qty < 1" do
      assert {:error, :min_qty_invalid} ==
               FractionalDiscount.validate(%{
                 @rule
                 | opts: %{min_qty: 0, numerator: 2, denominator: 3}
               })
    end

    test "rejects rule carrying a new_price" do
      assert {:error, :new_price_not_allowed} ==
               FractionalDiscount.validate(%{@rule | new_price: Money.new(0, :GBP)})
    end
  end

  test "opts_schema/0 exposes the three integer knobs" do
    schema = FractionalDiscount.opts_schema()
    assert {:min_qty, :integer, _} = List.keyfind(schema, :min_qty, 0)
    assert {:numerator, :integer, _} = List.keyfind(schema, :numerator, 0)
    assert {:denominator, :integer, _} = List.keyfind(schema, :denominator, 0)
  end
end
