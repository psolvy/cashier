defmodule Cashier.Pricing.Strategy do
  @moduledoc """
  Behaviour every pricing strategy implements.

  A strategy turns `(qty, unit_price, rule)` into a `Money.t()` line total.
  Implementations must be **pure**: no I/O, no process calls, no time.
  This keeps `Cashier.Pricing.Calculator` itself pure and trivially testable.

  ## Adding a new strategy

  1. Create a module implementing this behaviour.
  2. Add `{:new_atom, MyApp.MyStrategy}` to `Cashier.Pricing.Strategies`.
  3. (Optional) Expose its `opts_schema/0` to any future admin tool.

  No other code needs to change.
  """

  alias Cashier.Pricing.Rule

  @doc """
  Compute the line total for `qty` units of a product priced at `unit_price`,
  given the rule that selected this strategy.
  """
  @callback line_total(
              qty :: pos_integer(),
              unit_price :: Money.t(),
              rule :: Rule.t()
            ) :: {:ok, Money.t()} | {:error, term()}

  @doc "Validate that a rule's `opts` and `new_price` are well-formed for this strategy."
  @callback validate(rule :: Rule.t()) :: :ok | {:error, term()}

  @doc """
  Describe the strategy-specific opts/columns a UI would render.

  Each tuple is `{name, type, opts}` where `type` is `:integer` or `:money`
  and `opts` is a keyword list (`min:`, `label:`, …).
  """
  @callback opts_schema() :: [{atom(), :integer | :money, keyword()}]
end
