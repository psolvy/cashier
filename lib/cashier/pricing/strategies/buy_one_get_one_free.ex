defmodule Cashier.Pricing.Strategies.BuyOneGetOneFree do
  @moduledoc """
  Pay for every second unit; the alternates are free. `paid_count = div(qty + 1, 2)`.

      iex> alias Cashier.Pricing.Rule
      iex> rule = %Rule{id: 1, name: "BOGO", product_code: "GR1", strategy: :bogo}
      iex> {:ok, line} = Cashier.Pricing.Strategies.BuyOneGetOneFree.line_total(3, Money.new(311, :GBP), rule)
      iex> Money.to_string(line)
      "£6.22"
  """

  @behaviour Cashier.Pricing.Strategy

  alias Cashier.Pricing.Rule

  @impl true
  def line_total(qty, %Money{amount: price, currency: currency}, _rule) when is_integer(qty) and qty >= 1 do
    paid = div(qty + 1, 2)
    {:ok, Money.new(paid * price, currency)}
  end

  @impl true
  def validate(%Rule{opts: opts, new_price: new_price}) do
    cond do
      new_price != nil -> {:error, :new_price_not_allowed}
      opts != %{} -> {:error, :opts_not_allowed}
      true -> :ok
    end
  end

  @impl true
  def opts_schema, do: []
end
