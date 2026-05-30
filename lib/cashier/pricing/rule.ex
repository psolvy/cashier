defmodule Cashier.Pricing.Rule do
  @moduledoc """
  A pricing rule attached to one product code via a `strategy`.

    * `id`            — assigned by `Cashier.Pricing`.
    * `name`          — human label.
    * `product_code`  — references `Cashier.Catalog.Product` `code`.
    * `strategy`      — one of `Cashier.Pricing.Strategies.names/0`.
    * `opts`          — strategy-specific non-monetary arguments.
    * `new_price`     — used by strategies that swap in a different price (e.g. `:bulk_price_drop`).
    * `active`        — only active rules feed the calculator.
    * `priority`      — higher wins when multiple rules apply to one code.
    * `inserted_at`   — ties broken oldest-first.
  """

  @enforce_keys [:id, :name, :product_code, :strategy]
  defstruct [
    :id,
    :name,
    :product_code,
    :strategy,
    opts: %{},
    new_price: nil,
    active: true,
    priority: 0,
    inserted_at: nil
  ]

  @type strategy :: :bogo | :bulk_price_drop | :fractional_discount

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          product_code: String.t(),
          strategy: strategy(),
          opts: map(),
          new_price: Money.t() | nil,
          active: boolean(),
          priority: integer(),
          inserted_at: DateTime.t() | nil
        }
end
