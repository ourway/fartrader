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
      add :index, :float
      add :volume, :bigint
      add :trade_count, :bigint
      add :trade_value, :float
      add :cap, :bigint
      add :status, :string, null: false
      timestamps(type: :timestamptz)
    end

    create unique_index(:markets, [:name])

    create table(:stocks) do
      # ------------  CORE   -------------
      add :fa_symbol, :string
      add :ins_code, :string
      add :isin, :string
      add :cisin, :string
      add :en_symbol, :string
      add :fa_name, :string
      add :en_name, :string
      add :symbol, :string
      add :name, :string
      add :market_unit, :string
      add :base_volume, :bigint
      add :corp_name, :string
      add :market_type, :string
      add :industry, :string
      add :industry_code, :integer
      add :status, :string
      add :sub_industry, :string
      add :sub_industry_code, :integer
      timestamps(type: :timestamptz)
    end

    create index(:stocks, [:symbol])
    create index(:stocks, [:name])
    create index(:stocks, [:status])
    create unique_index(:stocks, [:isin])

    create table(:stock_data) do
      # -------------  DAY ---------------
      add :isin, :string
      add :quantity, :bigint
      add :pre_closing_price, :float
      add :first_traded_price, :float
      add :last_traded_price, :float
      add :best_limits, {:array, :map}
      add :buy_count_corp, :bigint
      add :buy_count_ind, :bigint
      add :buy_volume_corp, :bigint
      add :buy_volume_ind, :bigint
      add :market_value, :float
      add :max_allowed_price, :float
      add :max_allowed_volume, :bigint
      add :max_price, :float
      add :min_allowed_price, :float
      add :min_allowed_volume, :bigint
      add :min_price, :float
      add :sell_count_corp, :bigint
      add :sell_count_ind, :bigint
      add :sell_volume_corp, :bigint
      add :sell_volume_ind, :bigint
      add :status, :string
      add :queue_status, :string
      add :stock_holders, {:array, :map}
      add :trade_count, :bigint
      add :trade_total_price, :float
      add :trade_volume, :bigint
      add :closing_price, :float
      add :yesterday_closing_price, :float
      add :latest_trade_datetime, :timestamptz
      add :latest_trade_local_datetime, :string
      add :stock_id, references(:stocks)
      timestamps(type: :timestamptz)
    end

    create index(:stock_data, [:isin])
    create unique_index(:stock_data, [:isin, :latest_trade_datetime])
    # -----------  Crunched Data -----------------
    create table(:stock_stats) do
      add :isin, :string
      add :index_affect, :float
      add :estimated_eps, :float
      add :index_affect_rank, :float
      add :pe, :float
      add :sector_pe, :float
      add :profit_7_days, :float
      add :profit_30_days, :float
      add :profit_91_days, :float
      add :profit1_82_days, :float
      add :profit_365_days, :float
      add :profit_all_days, :float
      add :month_profit_rank, :int
      add :month_profit_rank_group, :int
      add :market_value_rank, :int
      add :market_value_rank_group, :int
      add :trade_volume_rank, :int
      add :trade_volume_rank_group, :int
      add :liquidity, :float
      add :correlation_with_dollar, :float
      add :correlation_with_gold, :float
      add :correlation_with_oil, :float
      add :correlation_with_market_index, :float
      add :online_interest_rank, :int
      add :stock_id, references(:stocks)
      # --------------------------------------------
      timestamps(type: :timestamptz)
    end

    create index(:stock_stats, [:isin])
    create index(:stock_stats, [:liquidity])

    create table(:tradeviews) do
      add :isin, :string
      add :unixtime, {:array, :bigint}
      add :closing_price, {:array, :float}
      add :highest_price, {:array, :float}
      add :lowest_price, {:array, :float}
      add :opening_price, {:array, :float}
      add :value, {:array, :float}
      add :stock_id, references(:stocks)

      timestamps(type: :timestamptz)
    end

    create unique_index(:tradeviews, [:isin])
  end
end
