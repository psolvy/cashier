defmodule Cashier.Checkout.SupervisorTest do
  use ExUnit.Case, async: false

  alias Cashier.Checkout

  setup do
    Cashier.Fixtures.seed_stores!()
    :ok
  end

  test "starts and stops checkout children" do
    {:ok, id} = Checkout.new()
    assert is_pid(Checkout.whereis(id))
    Checkout.stop(id)
    Process.sleep(10)
    assert Checkout.whereis(id) == nil
  end

  test "children are :temporary — they are not restarted on crash" do
    {:ok, id} = Checkout.new()
    pid = Checkout.whereis(id)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 200
    Process.sleep(20)
    assert Checkout.whereis(id) == nil
  end

  test "concurrent start_child works" do
    results =
      1..20
      |> Task.async_stream(fn _ -> Checkout.new() end, max_concurrency: 10)
      |> Enum.map(fn {:ok, {:ok, id}} -> id end)

    assert length(Enum.uniq(results)) == 20
    Enum.each(results, &Checkout.stop/1)
  end
end
