defmodule Cashier.Pricing.Strategies.FractionalDiscount do
  @moduledoc """
  When `qty >= min_qty`, multiply the line total by `numerator / denominator`
  using integer division (floor for non-negatives). Otherwise the original
  `unit_price` applies.

      iex> alias Cashier.Pricing.Rule
      iex> rule = %Rule{id: 1, name: "2/3", product_code: "CF1",
      ...>              strategy: :fractional_discount,
      ...>              opts: %{min_qty: 3, numerator: 2, denominator: 3}}
      iex> {:ok, line} = Cashier.Pricing.Strategies.FractionalDiscount.line_total(3, Money.new(1123, :GBP), rule)
      iex> Money.to_string(line)
      "£22.46"
  """

  @behaviour Cashier.Pricing.Strategy

  alias Cashier.Pricing.Rule

  @impl true
  def line_total(qty, %Money{amount: price, currency: currency}, %Rule{
        opts: %{min_qty: min_qty, numerator: n, denominator: d}
      })
      when is_integer(qty) and qty >= 1 and is_integer(min_qty) and is_integer(n) and is_integer(d) and d > 0 do
    if qty >= min_qty do
      {:ok, Money.new(div(qty * price * n, d), currency)}
    else
      {:ok, Money.new(qty * price, currency)}
    end
  end

  @impl true
  def validate(%Rule{opts: opts, new_price: new_price}) do
    with :ok <- check_no_new_price(new_price),
         :ok <- check_opts_map(opts),
         :ok <- check_min_qty(opts),
         :ok <- check_numerator(opts) do
      check_denominator(opts)
    end
  end

  defp check_no_new_price(nil), do: :ok
  defp check_no_new_price(_), do: {:error, :new_price_not_allowed}

  defp check_opts_map(opts) when is_map(opts), do: :ok
  defp check_opts_map(_), do: {:error, :opts_invalid}

  defp check_min_qty(%{min_qty: m}) when is_integer(m) and m >= 1, do: :ok
  defp check_min_qty(_), do: {:error, :min_qty_invalid}

  defp check_numerator(%{numerator: n}) when is_integer(n) and n >= 0, do: :ok
  defp check_numerator(_), do: {:error, :numerator_invalid}

  defp check_denominator(%{denominator: d}) when is_integer(d) and d >= 1, do: :ok
  defp check_denominator(_), do: {:error, :denominator_invalid}

  @impl true
  def opts_schema do
    [
      {:min_qty, :integer, min: 1, label: "Minimum quantity"},
      {:numerator, :integer, min: 0, label: "Numerator"},
      {:denominator, :integer, min: 1, label: "Denominator"}
    ]
  end
end
