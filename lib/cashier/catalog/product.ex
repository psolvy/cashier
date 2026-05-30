defmodule Cashier.Catalog.Product do
  @moduledoc """
  A product registered in the catalog.

    * `code`  — uppercase business identifier (e.g. `"GR1"`).
    * `name`  — human-readable label.
    * `price` — a `Money.t()` per unit.
  """

  @enforce_keys [:code, :name, :price]
  defstruct [:code, :name, :price]

  @type t :: %__MODULE__{
          code: String.t(),
          name: String.t(),
          price: Money.t()
        }
end
