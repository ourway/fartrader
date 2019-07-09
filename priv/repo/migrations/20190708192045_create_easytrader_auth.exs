defmodule FarTrader.Repo.Migrations.CreateEasytraderAuth do
  use Ecto.Migration

  def change do
    create table(:broker_credentials) do
      add :broker, :string, null: false
      add :nickname, :string, null: false
      add :username, :string, null: false
      add :password, :string, null: false
      add :credentials, :map, null: false, default: %{}
      add :credentials_expiration_datetime, :timestamptz

      timestamps(type: :timestamptz)
    end

    create unique_index(:broker_credentials, [:username, :broker])
    create unique_index(:broker_credentials, [:nickname, :broker])
  end
end
