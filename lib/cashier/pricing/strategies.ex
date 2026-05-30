defmodule Cashier.Pricing.Strategies do
  @moduledoc """
  Dispatch map from strategy name (atom) to implementing module. Single
  seam to edit when adding a new strategy; everywhere else uses `fetch/1`.
  """

  alias Cashier.Pricing.Strategies.BulkPriceDrop
  alias Cashier.Pricing.Strategies.BuyOneGetOneFree
  alias Cashier.Pricing.Strategies.FractionalDiscount

  @strategies %{
    bogo: BuyOneGetOneFree,
    bulk_price_drop: BulkPriceDrop,
    fractional_discount: FractionalDiscount
  }

  @doc "All registered strategies as a `name => module` map."
  @spec all() :: %{atom() => module()}
  def all, do: @strategies

  @doc "List of known strategy names."
  @spec names() :: [atom()]
  def names, do: Map.keys(@strategies)

  @doc """
  Look up the implementing module for a strategy name.

      iex> Cashier.Pricing.Strategies.fetch(:bogo)
      {:ok, Cashier.Pricing.Strategies.BuyOneGetOneFree}

      iex> Cashier.Pricing.Strategies.fetch(:unknown)
      :error
  """
  @spec fetch(atom()) :: {:ok, module()} | :error
  def fetch(name) when is_atom(name), do: Map.fetch(@strategies, name)
end
