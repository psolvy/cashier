defmodule Cashier.Pricing.Calculator do
  @moduledoc """
  Pure pricing engine. Given a basket (codes → quantities), a product
  catalog, and a per-code list of active rules, computes the total `Money`.

  No I/O, no process calls, no clock — trivially testable.

  ## Rule selection

  For each product code in the basket, the first rule in
  `rules_by_code[code]` wins. The caller is responsible for ordering
  (in this app: `priority` desc, `inserted_at` asc — done by
  `Cashier.Pricing.rules_for/1`). Codes with no rules fall back to
  `qty * unit_price`.

  ## Errors

    * `{:unknown_product, code}` — basket references a code missing
      from `products`.
    * `{:unknown_strategy, name}` — a rule names a strategy that is not
      in `Cashier.Pricing.Strategies.all/0`.
    * `{:currency_mismatch, code}` — a line's currency disagrees with
      the running total's currency.
  """

  alias Cashier.Catalog.Product
  alias Cashier.Pricing.Rule
  alias Cashier.Pricing.Strategies

  @type basket :: %{(code :: String.t()) => qty :: pos_integer()}
  @type products :: %{(code :: String.t()) => Product.t()}
  @type rules_by_code :: %{(code :: String.t()) => [Rule.t()]}

  @type error ::
          {:unknown_product, String.t()}
          | {:unknown_strategy, atom()}
          | {:currency_mismatch, String.t()}

  @doc "Compute the total for a basket. An empty basket totals to `Money.new(0, :GBP)`."
  @spec total(basket(), products(), rules_by_code()) :: {:ok, Money.t()} | {:error, error()}
  def total(basket, products, rules_by_code) when is_map(basket) and is_map(products) and is_map(rules_by_code) do
    with {:ok, lines} <- line_totals(basket, products, rules_by_code) do
      sum_lines(lines)
    end
  end

  @doc "Per-line breakdowns `[{code, qty, Money.t()}]` in basket-iteration order."
  @spec line_totals(basket(), products(), rules_by_code()) ::
          {:ok, [{String.t(), pos_integer(), Money.t()}]} | {:error, error()}
  def line_totals(basket, products, rules_by_code) when is_map(basket) and is_map(products) and is_map(rules_by_code) do
    basket
    |> Enum.reduce_while({:ok, []}, &reduce_line(&1, &2, products, rules_by_code))
    |> finalize_lines()
  end

  defp reduce_line({code, qty}, {:ok, acc}, products, rules_by_code) do
    with {:ok, product} <- fetch_product(products, code),
         {:ok, line} <- line_total(qty, product, rules_by_code[code] || []) do
      {:cont, {:ok, [{code, qty, line} | acc]}}
    else
      {:error, _} = err -> {:halt, err}
    end
  end

  defp finalize_lines({:ok, lines}), do: {:ok, Enum.reverse(lines)}
  defp finalize_lines(err), do: err

  defp sum_lines(lines) do
    Enum.reduce_while(lines, {:ok, Money.new(0, default_currency())}, &add_line/2)
  end

  defp add_line({code, _qty, line}, {:ok, acc}) do
    case add(acc, line, code) do
      {:ok, new_acc} -> {:cont, {:ok, new_acc}}
      {:error, _} = err -> {:halt, err}
    end
  end

  defp fetch_product(products, code) do
    case Map.fetch(products, code) do
      {:ok, %Product{} = product} -> {:ok, product}
      :error -> {:error, {:unknown_product, code}}
    end
  end

  defp line_total(qty, %Product{price: price}, []) do
    {:ok, Money.multiply(price, qty)}
  end

  defp line_total(qty, %Product{price: price}, [%Rule{strategy: name} = rule | _]) do
    case Strategies.fetch(name) do
      {:ok, module} -> module.line_total(qty, price, rule)
      :error -> {:error, {:unknown_strategy, name}}
    end
  end

  defp add(%Money{amount: 0, currency: _}, %Money{} = line, _code), do: {:ok, line}

  defp add(%Money{currency: c} = acc, %Money{currency: c} = line, _code) do
    {:ok, Money.add(acc, line)}
  end

  defp add(_acc, %Money{}, code), do: {:error, {:currency_mismatch, code}}

  defp default_currency do
    Application.get_env(:money, :default_currency, :GBP)
  end
end
