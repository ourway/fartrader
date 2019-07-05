defmodule FarTrader.Repo.Migrations.Symbol do
  use Ecto.Migration

  def change do
    execute("""

      CREATE OR REPLACE FUNCTION timestamp_update_func()
      RETURNS trigger AS
      $$

      DECLARE newhash varchar(72);
      DECLARE logbody varchar(256);
      DECLARE emailbody varchar(1024);

      BEGIN
      NEW.updated_at = now();
      IF OLD.inserted_at IS NULL THEN
        NEW.inserted_at = now();
      END IF;
      RETURN NEW;

      END;
      $$
      LANGUAGE 'plpgsql';

    """)

    create table(:markets) do
      add :name, :string, null: false
      add :index, :float, null: false
      add :volume, :bigint, null: false
      add :trade_count, :bigint, null: false
      add :cap, :bigint, null: false
      add :status, :string, null: false
      timestamps(type: :timestamptz)
    end

    create unique_index(:markets, [:name])

    #    execute("""
    #        CREATE TRIGGER users_timestamps_update_trigger
    #        BEFORE UPDATE OR INSERT
    #        ON markets
    #        FOR EACH ROW
    #          EXECUTE PROCEDURE timestamp_update_func();
    #    """)

    create table(:stocks) do
      add :symbol, :string, null: false
      add :name, :string, null: false
      add :isin, :string, null: false
      add :status, :string, default: "active", null: false
      add :last_price, :bigint, null: false
      add :last_price_interval, {:array, :bigint}
      add :last_start_price, :bigint
      add :closing_pirce, :bigint
      add :closing_pirce_change, :bigint
      add :closing_price_change_percent, :integer
      add :last_trade_price, :bigint
      add :last_trade_price_change, :bigint
      add :last_trade_price_change_percent, :integer
      add :eps, :bigint
      add :qn, :bigint
      add :pn, :bigint
      add :market_type, :string, null: false
      add :pe, :float
      add :allowed_price_range, {:array, :bigint}
      add :trade_count, :bigint
      add :trade_volume, :bigint
      add :ask, :bigint
      add :bid, :bigint
      add :effect_on_index, :float
      add :base_volume, :bigint
      add :market_cap, :bigint
      timestamps(type: :timestamptz)
    end

    create unique_index(:stocks, [:symbol])
    create unique_index(:stocks, [:name])
    create unique_index(:stocks, [:isin])
    create index(:stocks, [:status])
    create index(:stocks, [:pe])
    create index(:stocks, [:eps])
    create index(:stocks, [:effect_on_index])
    create index(:stocks, [:market_cap])
    create index(:stocks, [:isin, :status])
  end
end
