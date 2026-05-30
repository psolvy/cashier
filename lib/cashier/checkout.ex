defmodule Cashier.Checkout do
  @moduledoc """
  Public iex-facing facade for checkout sessions. Callers only need to
  remember the session id; each call resolves the underlying GenServer
  through `Cashier.CheckoutRegistry`.

      iex> {:ok, co} = Cashier.Checkout.new()
      iex> Enum.each(["GR1", "SR1", "GR1", "GR1", "CF1"], &Cashier.Checkout.scan(co, &1))
      iex> {:ok, total} = Cashier.Checkout.total(co)
      iex> Money.to_string(total)
      "£22.45"
  """

  @doc """
  Start a fresh checkout session.

    * `:idle_timeout_ms` — milliseconds of inactivity before the session
      self-terminates (default 30 minutes).
  """
  @spec new(keyword()) :: {:ok, String.t()} | {:error, term()}
  def new(opts \\ []) when is_list(opts) do
    id = uuid()

    case Cashier.Checkout.Supervisor.start_child(id, opts) do
      {:ok, _pid} -> {:ok, id}
      {:error, _} = err -> err
    end
  end

  @doc "Scan one unit of `code` into the session."
  @spec scan(String.t(), String.t()) ::
          {:ok, pos_integer()} | {:error, :unknown_product | :no_session}
  def scan(id, code) when is_binary(id) and is_binary(code), do: call(id, {:scan, code})

  @doc "Decrement / remove one unit of `code` from the session."
  @spec remove(String.t(), String.t()) :: :ok | {:error, term()}
  def remove(id, code) when is_binary(id) and is_binary(code), do: call(id, {:remove, code})

  @doc "Empty the basket without ending the session."
  @spec clear(String.t()) :: :ok | {:error, term()}
  def clear(id) when is_binary(id), do: call(id, :clear)

  @doc """
  List the session's basket as line entries — code, name, qty, line total.
  Each `line_total` is a `Money.t()` reflecting current rules.
  """
  @spec items(String.t()) :: {:ok, [map()]} | {:error, term()}
  def items(id) when is_binary(id), do: call(id, :items)

  @doc "Compute the session's current grand total. Always re-evaluated."
  @spec total(String.t()) :: {:ok, Money.t()} | {:error, term()}
  def total(id) when is_binary(id), do: call(id, :total)

  @doc "Stop the session. Subsequent calls return `{:error, :no_session}`."
  @spec stop(String.t()) :: :ok
  def stop(id) when is_binary(id) do
    case whereis(id) do
      nil -> :ok
      pid -> terminate_session(pid)
    end
  end

  defp terminate_session(pid) do
    case DynamicSupervisor.terminate_child(Cashier.Checkout.Supervisor, pid) do
      :ok -> :ok
      {:error, :not_found} -> :ok
    end
  end

  @doc "Look up the pid for a session id, or `nil` if none is alive."
  @spec whereis(String.t()) :: pid() | nil
  def whereis(id) when is_binary(id) do
    case Registry.lookup(Cashier.CheckoutRegistry, id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  defp call(id, message) do
    case whereis(id) do
      nil -> {:error, :no_session}
      pid -> GenServer.call(pid, message)
    end
  end

  defp uuid do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<a::32, b::16, c::16, d::16, e::48>> = <<u0::48, 0b0100::4, u1::12, 0b10::2, u2::62>>

    [a, b, c, d, e]
    |> Enum.zip([8, 4, 4, 4, 12])
    |> Enum.map_join("-", fn {n, w} ->
      n |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(w, "0")
    end)
  end
end
