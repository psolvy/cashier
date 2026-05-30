defmodule Cashier.Pricing.Strategies.BulkPriceDropTest do
  use ExUnit.Case, async: true

  alias Cashier.Pricing.Rule
  alias Cashier.Pricing.Strategies.BulkPriceDrop

  @rule %Rule{
    id: 1,
    name: "bulk",
    product_code: "SR1",
    strategy: :bulk_price_drop,
    opts: %{min_qty: 3},
    new_price: Money.new(450, :GBP)
  }
  @price Money.new(500, :GBP)

  describe "line_total/3" do
    test "below threshold uses unit_price" do
      assert {:ok, Money.new(1000, :GBP)} == BulkPriceDrop.line_total(2, @price, @rule)
    end

    test "at threshold uses new_price" do
      assert {:ok, Money.new(1350, :GBP)} == BulkPriceDrop.line_total(3, @price, @rule)
    end

    test "above threshold uses new_price" do
      assert {:ok, Money.new(2250, :GBP)} == BulkPriceDrop.line_total(5, @price, @rule)
    end

    test "currency mismatch is reported" do
      eur_rule = %{@rule | new_price: Money.new(450, :EUR)}

      assert {:error, {:currency_mismatch, :GBP, :EUR}} =
               BulkPriceDrop.line_total(3, @price, eur_rule)
    end
  end

  describe "validate/1" do
    test "accepts a well-formed rule" do
      assert :ok == BulkPriceDrop.validate(@rule)
    end

    test "rejects missing new_price" do
      assert {:error, :new_price_required} == BulkPriceDrop.validate(%{@rule | new_price: nil})
    end

    test "rejects invalid min_qty" do
      assert {:error, :min_qty_invalid} ==
               BulkPriceDrop.validate(%{@rule | opts: %{min_qty: 0}})
    end

    test "rejects negative new_price" do
      assert {:error, :new_price_negative} ==
               BulkPriceDrop.validate(%{@rule | new_price: Money.new(-1, :GBP)})
    end
  end

  test "opts_schema/0 exposes min_qty and new_price" do
    schema = BulkPriceDrop.opts_schema()
    assert {:min_qty, :integer, _} = List.keyfind(schema, :min_qty, 0)
    assert {:new_price, :money, _} = List.keyfind(schema, :new_price, 0)
  end
end
