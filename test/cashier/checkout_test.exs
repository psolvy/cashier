defmodule Cashier.CheckoutTest do
  use ExUnit.Case, async: false

  alias Cashier.Checkout

  setup do
    Cashier.Fixtures.seed_stores!()
    :ok
  end

  test "new/0 returns a UUIDv4-shaped id" do
    {:ok, id} = Checkout.new()
    assert is_binary(id)
    assert String.length(id) == 36

    assert Regex.match?(
             ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
             id
           )

    Checkout.stop(id)
  end

  test "whereis/1 returns nil for unknown ids" do
    assert nil == Checkout.whereis("definitely-not-a-real-id")
  end

  test "stop/1 is idempotent" do
    {:ok, id} = Checkout.new()
    assert :ok = Checkout.stop(id)
    assert :ok = Checkout.stop(id)
  end
end
