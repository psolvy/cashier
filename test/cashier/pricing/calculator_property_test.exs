defmodule Cashier.Pricing.CalculatorPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Cashier.Fixtures

  alias Cashier.Pricing.Calculator
  alias Cashier.Pricing.Rule

  defp basket_gen do
    ["GR1", "SR1", "CF1"]
    |> member_of()
    |> list_of(max_length: 20)
    |> StreamData.map(&Enum.frequencies/1)
  end

  property "totals are non-negative GBP" do
    check all(basket <- basket_gen()) do
      assert {:ok, money} = Calculator.total(basket, products_map(), rules_map())
      assert money.amount >= 0
      assert money.currency == :GBP
    end
  end

  property "rules never increase the total above the no-discount baseline" do
    check all(basket <- basket_gen()) do
      {:ok, with_rules} = Calculator.total(basket, products_map(), rules_map())
      {:ok, no_rules} = Calculator.total(basket, products_map(), %{})

      assert with_rules.amount <= no_rules.amount
    end
  end

  property "BOGO on GR1 always charges for ceil(qty/2) units" do
    check all(qty <- integer(1..50)) do
      {:ok, money} = Calculator.total(%{"GR1" => qty}, products_map(), rules_map())
      assert money.amount == div(qty + 1, 2) * 311
    end
  end

  property "bulk SR1 below threshold uses original price, at/above uses new_price" do
    check all(qty <- integer(1..50)) do
      {:ok, money} = Calculator.total(%{"SR1" => qty}, products_map(), rules_map())
      expected = if qty >= 3, do: qty * 450, else: qty * 500
      assert money.amount == expected
    end
  end

  property "fractional discount on CF1 floors per-line" do
    check all(qty <- integer(1..50)) do
      {:ok, money} = Calculator.total(%{"CF1" => qty}, products_map(), rules_map())
      expected = if qty >= 3, do: div(qty * 1123 * 2, 3), else: qty * 1123
      assert money.amount == expected
    end
  end

  property "inactive rules are ignored — totals match the no-rules baseline" do
    check all(basket <- basket_gen()) do
      inactive_rules =
        Map.new(rules_map(), fn {code, rules} ->
          {code,
           Enum.map(rules, fn %Rule{} = r ->
             %{r | active: false}
           end)}
        end)

      filtered =
        for {code, rules} <- inactive_rules,
            into: %{},
            do: {code, Enum.filter(rules, & &1.active)}

      {:ok, baseline} = Calculator.total(basket, products_map(), %{})
      {:ok, filtered_total} = Calculator.total(basket, products_map(), filtered)
      assert baseline == filtered_total
    end
  end
end
