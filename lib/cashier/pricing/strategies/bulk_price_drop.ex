defmodule Cashier.Pricing.Strategies.BulkPriceDrop do
  @moduledoc """
  When `qty >= min_qty`, every unit drops to `new_price`. Otherwise the
  original `unit_price` applies.

      iex> alias Cashier.Pricing.Rule
      iex> rule = %Rule{id: 1, name: "Bulk", product_code: "SR1",
      ...>              strategy: :bulk_price_drop,
      ...>              opts: %{min_qty: 3}, new_price: Money.new(450, :GBP)}
      iex> {:ok, line} = Cashier.Pricing.Strategies.BulkPriceDrop.line_total(3, Money.new(500, :GBP), rule)
      iex> Money.to_string(line)
      "£13.50"
  """

  @behaviour Cashier.Pricing.Strategy

  alias Cashier.Pricing.Rule

  @impl true
  def line_total(qty, %Money{amount: price, currency: currency}, %Rule{
        opts: %{min_qty: min_qty},
        new_price: %Money{amount: bulk_price, currency: bulk_currency}
      })
      when is_integer(qty) and qty >= 1 and is_integer(min_qty) do
    cond do
      currency != bulk_currency ->
        {:error, {:currency_mismatch, currency, bulk_currency}}

      qty >= min_qty ->
        {:ok, Money.new(qty * bulk_price, currency)}

      true ->
        {:ok, Money.new(qty * price, currency)}
    end
  end

  @impl true
  def validate(%Rule{opts: opts, new_price: new_price}) do
    cond do
      not is_map(opts) -> {:error, :opts_invalid}
      not match?(%Money{}, new_price) -> {:error, :new_price_required}
      not is_integer(opts[:min_qty]) or opts[:min_qty] < 1 -> {:error, :min_qty_invalid}
      new_price.amount < 0 -> {:error, :new_price_negative}
      true -> :ok
    end
  end

  @impl true
  def opts_schema do
    [
      {:min_qty, :integer, min: 1, label: "Minimum quantity"},
      {:new_price, :money, label: "Bulk price"}
    ]
  end
end
