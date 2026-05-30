defmodule Cashier.CatalogTest do
  use ExUnit.Case, async: false

  alias Cashier.Catalog

  setup do
    Cashier.Pricing.reset!()
    Catalog.reset!()
    :ok
  end

  describe "create/1" do
    test "inserts a valid product" do
      assert {:ok, product} =
               Catalog.create(%{code: "X1", name: "Item", price: Money.new(199, :GBP)})

      assert product.code == "X1"
      assert product.price == Money.new(199, :GBP)
    end

    test "normalises the code to uppercase" do
      {:ok, product} =
        Catalog.create(%{code: "  x1 ", name: "Item", price: Money.new(199, :GBP)})

      assert product.code == "X1"
      assert {:ok, ^product} = Catalog.get("x1")
    end

    test "rejects a duplicate code" do
      attrs = %{code: "DUP", name: "A", price: Money.new(100, :GBP)}
      {:ok, _} = Catalog.create(attrs)
      assert {:error, :code_taken} = Catalog.create(attrs)
    end

    test "rejects a negative price" do
      assert {:error, :price_negative} =
               Catalog.create(%{code: "NEG", name: "Bad", price: Money.new(-1, :GBP)})
    end

    test "rejects an empty name" do
      assert {:error, :name_required} =
               Catalog.create(%{code: "EMPTY", name: "  ", price: Money.new(100, :GBP)})
    end

    test "rejects malformed attrs" do
      assert {:error, :invalid_attrs} = Catalog.create(%{})
    end
  end

  describe "update/2" do
    setup do
      {:ok, product} =
        Catalog.create(%{code: "UP1", name: "First", price: Money.new(100, :GBP)})

      %{product: product}
    end

    test "updates the name", %{product: _product} do
      assert {:ok, updated} = Catalog.update("up1", %{name: "Renamed"})
      assert updated.name == "Renamed"
      assert {:ok, %{name: "Renamed"}} = Catalog.get("UP1")
    end

    test "updates the price" do
      assert {:ok, updated} = Catalog.update("UP1", %{price: Money.new(250, :GBP)})
      assert updated.price == Money.new(250, :GBP)
    end

    test "returns :not_found for missing code" do
      assert {:error, :not_found} = Catalog.update("nope", %{name: "X"})
    end

    test "validates the resulting price" do
      assert {:error, :price_negative} = Catalog.update("UP1", %{price: Money.new(-1, :GBP)})
    end
  end

  describe "delete/1" do
    test "removes an unreferenced product" do
      {:ok, _} = Catalog.create(%{code: "DEL", name: "X", price: Money.new(100, :GBP)})
      assert :ok = Catalog.delete("DEL")
      assert :error = Catalog.get("DEL")
    end

    test "refuses to delete a product referenced by a rule" do
      {:ok, _} = Catalog.create(%{code: "REF", name: "X", price: Money.new(100, :GBP)})

      {:ok, _} =
        Cashier.Pricing.create_rule(%{
          name: "ref",
          product_code: "REF",
          strategy: :bogo,
          opts: %{},
          new_price: nil
        })

      assert {:error, :referenced_by_rules} = Catalog.delete("REF")
    end

    test "returns :not_found for missing code" do
      assert {:error, :not_found} = Catalog.delete("missing")
    end
  end

  describe "list/0 and get/1" do
    test "returns products sorted by code" do
      {:ok, _} = Catalog.create(%{code: "B", name: "B", price: Money.new(1, :GBP)})
      {:ok, _} = Catalog.create(%{code: "A", name: "A", price: Money.new(1, :GBP)})
      assert ["A", "B"] = Enum.map(Catalog.list(), & &1.code)
    end

    test "get/1 is case-insensitive" do
      {:ok, _} = Catalog.create(%{code: "Mixed", name: "X", price: Money.new(1, :GBP)})
      assert {:ok, _} = Catalog.get("mixed")
      assert {:ok, _} = Catalog.get("MIXED")
    end
  end

  test "reads stay consistent under concurrent access" do
    {:ok, _} = Catalog.create(%{code: "CON", name: "X", price: Money.new(123, :GBP)})

    results =
      1..20
      |> Task.async_stream(fn _ -> Catalog.get("CON") end, max_concurrency: 10)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.all?(results, &match?({:ok, %{code: "CON"}}, &1))
  end
end
