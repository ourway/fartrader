defmodule FarTrader.Market do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "markets" do
    field :name, :string
    field :index, :float
    field :volume, :integer
    field :trade_count, :integer
    field :cap, :integer
    field :status, :string
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(market, attrs) do
    market
    |> cast(attrs, [
      :name,
      :index,
      :volume,
      :trade_count,
      :cap,
      :status
    ])
    |> validate_required([:name, :index, :volume, :trade_count, :cap, :status])
  end
end
