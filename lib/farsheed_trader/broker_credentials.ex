defmodule FarTrader.BrokerCredentials do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Adapters.SQL
  alias Ecto.InvalidChangesetError

  schema ":broker_credentials" do
    field :broker, :string
    field :nickname, :string
    field :username, :string
    field :password, :string
    field :credetentials, :map, default: %{}
    field :credetentials_expiration_datetime, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(broker_credentials, attrs) do
    broker_credentials
    |> cast(attrs, [
      :broker,
      :username,
      :nickname,
      :password,
      :credetentials,
      :credetentials_expiration_datetime
    ])
    |> validate_required([:broker, :username, :password, :nickname])
  end
end
