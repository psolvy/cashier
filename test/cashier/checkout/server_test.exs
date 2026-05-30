defmodule Cashier.Checkout.ServerTest do
  use ExUnit.Case, async: false

  alias Cashier.Checkout

  setup do
    Cashier.Fixtures.seed_stores!()
    :ok
  end

  test "scan increments qty and returns the new count" do
    {:ok, id} = Checkout.new()
    assert {:ok, 1} = Checkout.scan(id, "GR1")
    assert {:ok, 2} = Checkout.scan(id, "GR1")
    assert :ok = Checkout.stop(id)
  end

  test "scan reports unknown products" do
    {:ok, id} = Checkout.new()
    assert {:error, :unknown_product} = Checkout.scan(id, "ZZ9")
    Checkout.stop(id)
  end

  test "items/1 returns line entries" do
    {:ok, id} = Checkout.new()
    Checkout.scan(id, "GR1")
    Checkout.scan(id, "GR1")
    assert {:ok, [%{code: "GR1", qty: 2, line_total: line}]} = Checkout.items(id)
    assert line == Money.new(311, :GBP)
    Checkout.stop(id)
  end

  test "total matches the brief's first basket" do
    {:ok, id} = Checkout.new()
    Enum.each(["GR1", "SR1", "GR1", "GR1", "CF1"], &Checkout.scan(id, &1))
    assert {:ok, Money.new(2245, :GBP)} == Checkout.total(id)
    Checkout.stop(id)
  end

  test "remove/2 decrements qty and finally removes the line" do
    {:ok, id} = Checkout.new()
    Checkout.scan(id, "GR1")
    Checkout.scan(id, "GR1")
    assert :ok = Checkout.remove(id, "GR1")
    assert {:ok, [%{qty: 1}]} = Checkout.items(id)
    assert :ok = Checkout.remove(id, "GR1")
    assert {:ok, []} = Checkout.items(id)
    Checkout.stop(id)
  end

  test "clear/1 empties the basket" do
    {:ok, id} = Checkout.new()
    Checkout.scan(id, "GR1")
    assert :ok = Checkout.clear(id)
    assert {:ok, []} = Checkout.items(id)
    Checkout.stop(id)
  end

  test "session id is unregistered after stop" do
    {:ok, id} = Checkout.new()
    assert Checkout.whereis(id)
    Checkout.stop(id)
    Process.sleep(10)
    assert Checkout.whereis(id) == nil
  end

  test "facade returns :no_session for unknown ids" do
    assert {:error, :no_session} = Checkout.scan("not-a-real-id", "GR1")
    assert {:error, :no_session} = Checkout.total("not-a-real-id")
  end

  test "idle timeout terminates the session" do
    id = "test-idle-#{System.unique_integer([:positive])}"
    {:ok, pid} = Cashier.Checkout.Supervisor.start_child(id, idle_timeout_ms: 0)
    ref = Process.monitor(pid)
    send(pid, :idle_check)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500
  end
end
