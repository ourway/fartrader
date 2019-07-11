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

    create table(:companies) do
      add :fa_name, :string, null: false
      add :en_name, :string, null: false
      add :isin, :string, null: false
      add :cisin, :string, null: false
      add :en_symbol, :string
      add :fa_symbol, :string
      add :market_type, :string
      add :industry, :string
      add :industry_code, :integer
      add :sub_industry, :string
      add :sub_industry_code, :string

      timestamps(type: :timestamptz)
    end

    #    execute("""
    #        CREATE TRIGGER users_timestamps_update_trigger
    #        BEFORE UPDATE OR INSERT
    #        ON markets
    #        FOR EACH ROW
    #          EXECUTE PROCEDURE timestamp_update_func();
    #    """)

    create table(:stocks) do
      add :fa_symbol, :string
      add :symbol, :string
      add :en_symbol, :string
      add :fa_name, :string
      add :en_name, :string
      add :name, :string
      add :market_unit, :string
      add :isin, :string, null: false
      add :adtv, :bigint
      add :base_volume, :bigint
      add :day_min_allowed_quantity, :bigint
      add :day_max_allowed_quantity, :bigint
      add :day_closing_price, :float
      add :yesterday_closing_price, :float
      add :day_best_ask, :float
      add :day_best_bid, :float
      add :day_number_of_shares_bought_at_best_ask, :bigint
      add :day_number_of_shares_sold_at_best_bid, :bigint
      add :day_closing_price_change, :float
      add :day_closing_price_change_percent, :float
      add :day_price_change, :float
      add :day_price_change_percent, :float
      add :total_traded_value, :float
      add :day_traded_value, :float
      add :total_number_traded_shares, :bigint
      add :day_number_of_traded_shares, :bigint
      add :day_last_traded_price, :float
      add :day_min_allowed_price, :float
      add :day_max_allowed_price, :float
      add :day_low_price, :float
      add :day_high_price, :float
      add :effect_on_index, :float
      add :day_latest_trade_datetime, :timestamptz
      add :day_latest_trade_local_datetime, :string
      add :status, :string, default: "active", null: false
      add :depth, :map, default: %{}
      add :company_id, references(:companies, on_delete: :delete_all)
      timestamps(type: :timestamptz)
    end

    create index(:stocks, [:symbol])
    create index(:stocks, [:name])
    create unique_index(:stocks, [:isin])
  end
end
