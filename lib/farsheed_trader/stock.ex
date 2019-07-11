defmodule FarTrader.Stock do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "stocks" do
    field :fa_symbol, :string
    field :symbol, :string
    field :en_symbol, :string
    field :fa_name, :string
    field :en_name, :string
    field :name, :string
    field :market_unit, :string
    field :isin, :string
    field :adtv, :integer
    field :base_volume, :integer
    field :day_min_allowed_quantity, :integer
    field :day_max_allowed_quantity, :integer
    field :day_closing_price, :float
    field :yesterday_closing_price, :float
    field :day_best_ask, :float
    field :day_best_bid, :float
    field :day_number_of_shares_bought_at_best_ask, :integer
    field :day_number_of_shares_sold_at_best_bid, :integer
    field :day_closing_price_change, :float
    field :day_closing_price_change_percent, :float
    field :day_price_change, :float
    field :day_price_change_percent, :float
    field :total_traded_value, :float
    field :day_traded_value, :float
    field :total_number_traded_shares, :integer
    field :day_number_of_traded_shares, :integer
    field :day_last_traded_price, :float
    field :day_min_allowed_price, :float
    field :day_max_allowed_price, :float
    field :day_low_price, :float
    field :day_high_price, :float
    field :effect_on_index, :float
    field :day_latest_trade_datetime, :utc_datetime_usec
    field :day_latest_trade_local_datetime, :string
    field :status, :string, default: "active"
    field :depth, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(market, attrs) do
    market
    |> cast(attrs, [
      :fa_symbol,
      :symbol,
      :en_symbol,
      :fa_name,
      :en_name,
      :name,
      :market_unit,
      :isin,
      :adtv,
      :base_volume,
      :day_min_allowed_quantity,
      :day_max_allowed_quantity,
      :day_closing_price,
      :yesterday_closing_price,
      :day_best_ask,
      :day_best_bid,
      :day_number_of_shares_bought_at_best_ask,
      :day_number_of_shares_sold_at_best_bid,
      :day_closing_price_change,
      :day_closing_price_change_percent,
      :day_price_change,
      :day_price_change_percent,
      :total_traded_value,
      :day_traded_value,
      :total_number_traded_shares,
      :day_number_of_traded_shares,
      :day_last_traded_price,
      :day_min_allowed_price,
      :day_max_allowed_price,
      :day_low_price,
      :day_high_price,
      :effect_on_index,
      :day_latest_trade_datetime,
      :day_latest_trade_local_datetime,
      :status,
      :depth
    ])
    |> validate_required([:isin, :symbol])
  end
end
