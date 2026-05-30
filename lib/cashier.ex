defmodule Cashier do
  @moduledoc """
  Top-level convenience module for the Cashier OTP application.

  The interesting surface lives in:

    * `Cashier.Checkout` — open a session, scan items, compute totals.
    * `Cashier.Catalog`  — list / create / update / delete products.
    * `Cashier.Pricing`  — list / create / update / delete pricing rules.
    * `Cashier.Loader`   — re-seed the in-memory stores from `Cashier.Initial`.

  ## Quick demo

      iex> {:ok, co} = Cashier.Checkout.new()
      iex> Enum.each(["GR1", "SR1", "GR1", "GR1", "CF1"], &Cashier.Checkout.scan(co, &1))
      iex> {:ok, total} = Cashier.Checkout.total(co)
      iex> Money.to_string(total)
      "£22.45"
  """
end
