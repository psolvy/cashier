defmodule Cashier.Pricing.CalculatorTest do
  use ExUnit.Case, async: true

  import Cashier.Fixtures

  alias Cashier.Catalog.Product
  alias Cashier.Pricing.Calculator

  describe "the Kantox brief's four baskets" do
    setup do
      %{products: products_map(), rules: rules_map()}
    end

    test "GR1,SR1,GR1,GR1,CF1 totals £22.45", %{products: products, rules: rules} do
      assert {:ok, money} = Calculator.total(basket("GR1,SR1,GR1,GR1,CF1"), products, rules)
      assert money == Money.new(2245, :GBP)
    end

    test "GR1,GR1 totals £3.11", %{products: products, rules: rules} do
      assert {:ok, money} = Calculator.total(basket("GR1,GR1"), products, rules)
      assert money == Money.new(311, :GBP)
    end

    test "SR1,SR1,GR1,SR1 totals £16.61", %{products: products, rules: rules} do
      assert {:ok, money} = Calculator.total(basket("SR1,SR1,GR1,SR1"), products, rules)
      assert money == Money.new(1661, :GBP)
    end

    test "GR1,CF1,SR1,CF1,CF1 totals £30.57", %{products: products, rules: rules} do
      assert {:ok, money} = Calculator.total(basket("GR1,CF1,SR1,CF1,CF1"), products, rules)
      assert money == Money.new(3057, :GBP)
    end
  end

  describe "line_totals/3" do
    setup do
      %{products: products_map(), rules: rules_map()}
    end

    test "returns one entry per basket code with per-line totals", %{products: p, rules: r} do
      {:ok, lines} = Calculator.line_totals(basket("GR1,SR1,GR1,GR1,CF1"), p, r)
      by_code = Map.new(lines, fn {code, qty, line} -> {code, {qty, line}} end)

      assert by_code["GR1"] == {3, Money.new(622, :GBP)}
      assert by_code["SR1"] == {1, Money.new(500, :GBP)}
      assert by_code["CF1"] == {1, Money.new(1123, :GBP)}
    end

    test "sums of lines match Calculator.total/3", %{products: p, rules: r} do
      basket = basket("GR1,CF1,SR1,CF1,CF1")
      {:ok, lines} = Calculator.line_totals(basket, p, r)
      {:ok, total} = Calculator.total(basket, p, r)

      sum =
        Enum.reduce(lines, 0, fn {_code, _qty, %Money{amount: a}}, acc -> acc + a end)

      assert sum == total.amount
    end

    test "surfaces unknown products like total/3 does", %{products: p, rules: r} do
      assert {:error, {:unknown_product, "ZZ9"}} =
               Calculator.line_totals(%{"ZZ9" => 1}, p, r)
    end
  end

  describe "edge cases" do
    test "empty basket totals to zero GBP" do
      assert {:ok, Money.new(0, :GBP)} == Calculator.total(%{}, products_map(), rules_map())
    end

    test "unknown product surfaces as :unknown_product" do
      assert {:error, {:unknown_product, "ZZ9"}} =
               Calculator.total(%{"ZZ9" => 1}, products_map(), rules_map())
    end

    test "unknown strategy surfaces as :unknown_strategy" do
      products = products_map()

      rules = %{
        "GR1" => [
          %Cashier.Pricing.Rule{
            id: 99,
            name: "unknown",
            product_code: "GR1",
            strategy: :does_not_exist,
            inserted_at: DateTime.utc_now()
          }
        ]
      }

      assert {:error, {:unknown_strategy, :does_not_exist}} =
               Calculator.total(%{"GR1" => 1}, products, rules)
    end

    test "no rules for a product falls back to qty * price" do
      products = products_map()
      assert {:ok, money} = Calculator.total(%{"GR1" => 3}, products, %{})
      assert money == Money.new(3 * 311, :GBP)
    end

    test "currency mismatch surfaces as :currency_mismatch" do
      products = %{
        "GR1" => %Product{code: "GR1", name: "GR1", price: Money.new(100, :GBP)},
        "EX1" => %Product{code: "EX1", name: "EX1", price: Money.new(100, :EUR)}
      }

      assert {:error, {:currency_mismatch, code}} =
               Calculator.total(%{"GR1" => 1, "EX1" => 1}, products, %{})

      assert code in ["GR1", "EX1"]
    end
  end
end
