defmodule FarTrader.MarketTest do
  use FarTrader.DataCase, async: true
  alias FarTrader.Market

  test "insert market data" do
    cs =
      Market.changeset(
        %Market{
          name: "main",
          index: 1.24,
          volume: 10,
          trade_count: 2,
          cap: 100,
          status: "closed"
        },
        %{}
      )

    assert cs.valid?

    m = cs |> Repo.insert!()
    assert m.cap == 100
  end
end
