defmodule FarTrader.Stock do
  @moduledoc false
  alias FarTrader.StockData
  use Ecto.Schema
  import Ecto.Changeset

  schema "stocks" do
    field :fa_symbol, :string
    field :ins_code, :string
    field :isin, :string
    field :cisin, :string
    field :en_symbol, :string
    field :fa_name, :string
    field :en_name, :string
    field :symbol, :string
    field :name, :string
    field :market_unit, :string
    field :base_volume, :integer
    field :corp_name, :string
    field :market_type, :string
    field :industry, :string
    field :industry_code, :integer
    field :status, :string
    field :sub_industry, :string
    field :sub_industry_code, :string
    has_many :stock_data, StockData
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(stock, attrs) do
    stock
    |> cast(attrs, [
      :fa_symbol,
      :ins_code,
      :isin,
      :cisin,
      :en_symbol,
      :fa_name,
      :en_name,
      :symbol,
      :name,
      :market_unit,
      :base_volume,
      :corp_name,
      :market_type,
      :industry,
      :industry_code,
      :status,
      :sub_industry,
      :sub_industry_code
    ])
    |> validate_required([:isin, :symbol])
    |> cast_assoc(:stock_data)
  end
end
