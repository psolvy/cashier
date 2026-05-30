defmodule Cashier.IntegrationTest do
  @moduledoc """
  End-to-end exercise of the live application: seed → open checkouts via
  the public `Cashier.Checkout` facade → verify totals → mutate the
  catalog via admin CRUD → confirm a fresh checkout sees the new prices.
  """

  use ExUnit.Case, async: false

  alias Cashier.Checkout

  setup do
    Cashier.Fixtures.seed_stores!()
    :ok
  end

  describe "the brief's four baskets via Cashier.Checkout" do
    for {basket_string, total_cents} <- [
          {"GR1,SR1,GR1,GR1,CF1", 2245},
          {"GR1,GR1", 311},
          {"SR1,SR1,GR1,SR1", 1661},
          {"GR1,CF1,SR1,CF1,CF1", 3057}
        ] do
      @basket basket_string
      @cents total_cents

      test "#{basket_string} totals £#{Float.round(total_cents / 100, 2)}" do
        {:ok, id} = Checkout.new()
        for code <- String.split(@basket, ",", trim: true), do: Checkout.scan(id, code)
        assert {:ok, Money.new(@cents, :GBP)} == Checkout.total(id)
        Checkout.stop(id)
      end
    end
  end

  test "admin CRUD: changing SR1 price propagates to a fresh checkout" do
    {:ok, _} = Cashier.Catalog.update("SR1", %{price: Money.new(600, :GBP)})

    {:ok, id} = Checkout.new()
    for _ <- 1..2, do: Checkout.scan(id, "SR1")
    assert {:ok, Money.new(1200, :GBP)} == Checkout.total(id)
    Checkout.stop(id)
  end

  test "admin CRUD: deactivating the BOGO rule changes GR1 totals" do
    [bogo] = Enum.filter(Cashier.Pricing.list_rules(), &(&1.strategy == :bogo))
    {:ok, _} = Cashier.Pricing.deactivate(bogo.id)

    {:ok, id} = Checkout.new()
    Checkout.scan(id, "GR1")
    Checkout.scan(id, "GR1")
    assert {:ok, Money.new(2 * 311, :GBP)} == Checkout.total(id)
    Checkout.stop(id)
  end

  test "admin CRUD: adding a new product is immediately scannable" do
    {:ok, _} =
      Cashier.Catalog.create(%{code: "TEA2", name: "Earl Grey", price: Money.new(250, :GBP)})

    {:ok, id} = Checkout.new()
    assert {:ok, 1} = Checkout.scan(id, "TEA2")
    assert {:ok, Money.new(250, :GBP)} == Checkout.total(id)
    Checkout.stop(id)
  end
end
