defmodule FarTrader.DataCore do
  @moduledoc false
  alias FarTrader.ExternalData
  alias FarTrader.Market
  alias FarTrader.Repo
  alias FarTrader.Utils

  def update_market do
    status =
      case Utils.market_open?() do
        true ->
          "open"

        false ->
          "closed"
      end

    basic_info = ExternalData.market_basic_info()
    cs = basic_info |> FarTrader.Market.changeset(%{status: status})

    case Market |> Repo.one() do
      nil ->
        {:ok, _m} = cs |> Repo.insert()

      m ->
        m |> Market.changeset(%{basic_info | status: status})
    end
  end
end
