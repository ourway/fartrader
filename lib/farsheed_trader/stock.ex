defmodule FarTrader.Stock do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "stocks" do
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(market, attrs) do
    market
    |> cast(attrs, [])
    |> validate_required([])
  end
end
