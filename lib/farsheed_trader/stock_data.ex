defmodule FarTrader.StockData do
  @moduledoc false
  alias FarTrader.Stock
  use Ecto.Schema
  import Ecto.Changeset

  schema "stock_data" do
    field :isin, :string
    field :adtv, :integer
    field :quantity, :integer
    field :value, :float
    field :pre_closing_price, :float
    field :first_traded_price, :float
    field :last_traded_price, :float
    field :closing_price, :float
    field :best_buy_quantity, :integer
    field :best_buy_price, :float
    field :best_sell_price, :float
    field :best_sell_quantity, :integer
    field :best_limits, {:array, :map}
    field :buy_count_corp, :integer
    field :buy_count_ind, :integer
    field :buy_volume_corp, :integer
    field :buy_volume_ind, :integer
    field :market_value, :float
    field :max_allow_price, :float
    field :max_allow_volume, :integer
    field :max_price, :float
    field :min_allow_price, :float
    field :min_allow_volume, :integer
    field :min_price, :float
    field :sell_count_corp, :integer
    field :sell_count_ind, :integer
    field :sell_volume_corp, :integer
    field :sell_volume_ind, :integer
    field :status, :string
    field :queue_status, :string
    field :stock_holders, {:array, :map}
    field :total_count, :integer
    field :trade_count, :integer
    field :trade_total_price, :float
    field :trade_volume, :integer
    field :yesterday_closing_price, :float
    field :latest_trade_datetime, :utc_datetime_usec
    field :latest_trade_local_datetime, :string

    belongs_to :stocks, Stock

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(stock_data, attrs) do
    stock_data
    |> cast(attrs, [
      :isin,
      :adtv,
      :quantity,
      :value,
      :pre_closing_price,
      :first_traded_price,
      :last_traded_price,
      :closing_price,
      :best_buy_quantity,
      :best_buy_price,
      :best_sell_price,
      :best_sell_quantity,
      :best_limits,
      :buy_count_corp,
      :buy_count_ind,
      :buy_volume_corp,
      :buy_volume_ind,
      :market_value,
      :max_allow_price,
      :max_allow_volume,
      :max_price,
      :min_allow_price,
      :min_allow_volume,
      :min_price,
      :sell_count_corp,
      :sell_count_ind,
      :sell_volume_corp,
      :sell_volume_ind,
      :status,
      :queue_status,
      :stock_holders,
      :total_count,
      :trade_count,
      :trade_total_price,
      :trade_volume,
      :yesterday_closing_price,
      :latest_trade_datetime,
      :latest_trade_local_datetime
    ])
    |> validate_required([:isin, :closing_price, :latest_trade_local_datetime])
    |> cast_assoc(:stock)
  end
end
