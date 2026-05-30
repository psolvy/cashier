import Config

config :logger, level: :info

config :money,
  default_currency: :GBP,
  symbol: true,
  symbol_on_right: false,
  symbol_space: false,
  fractional_unit: true
