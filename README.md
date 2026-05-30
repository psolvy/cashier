# Cashier

[![CI](https://github.com/psolvy/cashier/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/psolvy/cashier/actions/workflows/ci.yml?query=branch%3Amaster)

A pure-OTP supermarket cashier service. Stateful checkout sessions, an
in-memory product catalog, a flexible pricing-rule store, and a pure
calculation engine — all behind an `iex` interface. No web, no database.

## Quick start

```bash
mix deps.get
iex -S mix
```

```elixir
iex> {:ok, co} = Cashier.Checkout.new()
iex> Enum.each(["GR1", "SR1", "GR1", "GR1", "CF1"], &Cashier.Checkout.scan(co, &1))
iex> {:ok, total} = Cashier.Checkout.total(co)
iex> Money.to_string(total)
"£22.45"
```

The four baskets from the brief, verified end-to-end:

| Basket                | Expected |
| --------------------- | -------- |
| `GR1,SR1,GR1,GR1,CF1` | £22.45   |
| `GR1,GR1`             | £3.11    |
| `SR1,SR1,GR1,SR1`     | £16.61   |
| `GR1,CF1,SR1,CF1,CF1` | £30.57   |

## Architecture

```
Cashier.Application
└── Cashier.Supervisor (one_for_one)
    ├── Registry (Cashier.CheckoutRegistry)
    ├── Cashier.Catalog          (GenServer + protected ETS)
    ├── Cashier.Pricing          (GenServer + protected ETS)
    ├── Cashier.Loader           (Task, restart :transient)
    └── Cashier.Checkout.Supervisor (DynamicSupervisor)
        └── Cashier.Checkout.Server (one per session, :temporary)
```

Reads hit ETS directly; writes go through the owning GenServer. The
pricing calculator is a pure module called on every `:total` request,
so admin rule edits affect the next total with no subscription dance.

## Admin (iex) CRUD

```elixir
Cashier.Catalog.list()
Cashier.Catalog.create(%{code: "TEA2", name: "Earl Grey", price: Money.new(250, :GBP)})
Cashier.Catalog.update("TEA2", %{price: Money.new(300, :GBP)})
Cashier.Catalog.delete("TEA2")

Cashier.Pricing.list_rules()
Cashier.Pricing.create_rule(%{
  name: "Demo bulk",
  product_code: "TEA2",
  strategy: :bulk_price_drop,
  opts: %{min_qty: 5},
  new_price: Money.new(200, :GBP)
})
Cashier.Pricing.deactivate(rule_id)
Cashier.Pricing.delete_rule(rule_id)

Cashier.Loader.load!()
```

## Adding a pricing strategy

1. Implement `Cashier.Pricing.Strategy` in a new module.
2. Register it in `Cashier.Pricing.Strategies`.

## Gates

```bash
mix test
mix coveralls
mix format --check-formatted
mix credo --strict
mix dialyzer
mix deps.audit
mix hex.audit
mix deps.unlock --check-unused
```

Coverage gate is 80%; the suite runs at ~95%. CI runs all of these on
every push and PR — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).
