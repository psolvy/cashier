defmodule Cashier.PricingTest do
  use ExUnit.Case, async: false

  alias Cashier.Pricing

  setup do
    Pricing.reset!()
    Cashier.Catalog.reset!()

    {:ok, _} =
      Cashier.Catalog.create(%{code: "GR1", name: "GR1", price: Money.new(311, :GBP)})

    {:ok, _} =
      Cashier.Catalog.create(%{code: "SR1", name: "SR1", price: Money.new(500, :GBP)})

    :ok
  end

  describe "create_rule/1" do
    test "inserts a BOGO rule" do
      assert {:ok, rule} =
               Pricing.create_rule(%{
                 name: "BOGO",
                 product_code: "GR1",
                 strategy: :bogo
               })

      assert rule.id == 1
      assert rule.product_code == "GR1"
      assert rule.strategy == :bogo
      assert rule.active == true
    end

    test "rejects an unknown strategy" do
      assert {:error, {:unknown_strategy, :bogus}} =
               Pricing.create_rule(%{name: "x", product_code: "GR1", strategy: :bogus})
    end

    test "rejects a rule pointing at a product code that does not exist" do
      assert {:error, {:unknown_product, "MISSING"}} =
               Pricing.create_rule(%{name: "x", product_code: "MISSING", strategy: :bogo})
    end

    test "rejects duplicate (product_code, strategy) combos" do
      attrs = %{name: "x", product_code: "GR1", strategy: :bogo}
      {:ok, _} = Pricing.create_rule(attrs)
      assert {:error, :rule_already_exists} = Pricing.create_rule(attrs)
    end

    test "bulk_price_drop requires new_price" do
      assert {:error, :new_price_required} =
               Pricing.create_rule(%{
                 name: "bulk",
                 product_code: "SR1",
                 strategy: :bulk_price_drop,
                 opts: %{min_qty: 3}
               })
    end

    test "normalises the product_code to uppercase" do
      {:ok, rule} =
        Pricing.create_rule(%{name: "x", product_code: " gr1 ", strategy: :bogo})

      assert rule.product_code == "GR1"
    end
  end

  describe "update_rule/2" do
    setup do
      {:ok, rule} = Pricing.create_rule(%{name: "x", product_code: "GR1", strategy: :bogo})
      %{rule: rule}
    end

    test "toggles active flag", %{rule: rule} do
      assert {:ok, %{active: false}} = Pricing.deactivate(rule.id)
      assert {:ok, %{active: true}} = Pricing.activate(rule.id)
    end

    test "returns :not_found for missing id" do
      assert {:error, :not_found} = Pricing.update_rule(999, %{active: false})
    end

    test "updates priority", %{rule: rule} do
      assert {:ok, %{priority: 5}} = Pricing.update_rule(rule.id, %{priority: 5})
    end
  end

  describe "rules_for/1 and ordering" do
    test "returns only active rules for that code" do
      {:ok, r1} = Pricing.create_rule(%{name: "a", product_code: "GR1", strategy: :bogo})
      r1_id = r1.id
      {:ok, _r_inactive} = Pricing.deactivate(r1_id)
      assert [] = Pricing.rules_for("GR1")

      {:ok, _} = Pricing.activate(r1_id)
      assert [%{id: ^r1_id}] = Pricing.rules_for("GR1")
    end

    test "sorts by priority desc then inserted_at asc" do
      {:ok, _} =
        Pricing.create_rule(%{name: "a", product_code: "GR1", strategy: :bogo, priority: 0})

      {:ok, b} =
        Pricing.create_rule(%{
          name: "b",
          product_code: "SR1",
          strategy: :bulk_price_drop,
          opts: %{min_qty: 2},
          new_price: Money.new(300, :GBP),
          priority: 5
        })

      rules = Pricing.list_rules()
      assert hd(rules).id == b.id
    end
  end

  describe "delete_rule/1" do
    test "removes a rule" do
      {:ok, rule} = Pricing.create_rule(%{name: "x", product_code: "GR1", strategy: :bogo})
      assert :ok = Pricing.delete_rule(rule.id)
      assert [] = Pricing.list_rules()
    end

    test "returns :not_found for missing id" do
      assert {:error, :not_found} = Pricing.delete_rule(999)
    end
  end

  describe "referenced?/1" do
    test "true when any rule references the code" do
      {:ok, _} = Pricing.create_rule(%{name: "x", product_code: "GR1", strategy: :bogo})
      assert Pricing.referenced?("GR1")
      assert Pricing.referenced?("gr1")
    end

    test "false otherwise" do
      refute Pricing.referenced?("GR1")
    end
  end
end
