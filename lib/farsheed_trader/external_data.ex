defmodule FarTrader.ExternalData do
  @moduledoc false
  alias FarTrader.Market
  alias FarTrader.Utils
  alias FarTrader.Repo
  alias FarTrader.Stock
  # import Ecto.Query, only: [from: 2]

  @doc "get's chart history data from sahamyab.com"
  def tradingview_history(isin) do
    stock = Stock |> Repo.get_by(isin: isin)

    url =
      "https://www.sahamyab.com/guest/tradingview/history?adjustment=&symbol=#{stock.fa_symbol}&from=1&to=999999999999999"
      |> URI.encode()

    %HTTPoison.Response{:status_code => 200, :body => body} = Utils.http_get(url)
    body |> Jason.decode()
  end

  @doc "gets market overview from `tse.ir`"
  @spec tse_overview() :: map()
  def tse_overview do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "http://tse.ir/json/MarketWatch/data_1.json?_=#{epoch}"

    headers = [
      "Content-Type": "application/json",
      Accept: "Application/json; Charset=utf-8",
      Host: "tse.ir",
      Referer: "Referer: http://tse.ir/MarketWatch.html?cat=cash"
    ]

    {:ok, %HTTPoison.Response{:status_code => 200, :body => body}} = HTTPoison.get(url, headers)
    {:ok, resp} = body |> Jason.decode()
    resp
  end

  @doc "gets market info `tse.ir`"
  @spec tse_market() :: map()
  def tse_market do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "http://tse.ir/json/HomePage/tabData.json?_=#{epoch}"

    headers = [
      "Content-Type": "application/json",
      Accept: "Application/json; Charset=utf-8",
      Host: "tse.ir",
      Referer: "Referer: http://tse.ir/"
    ]

    {:ok, %HTTPoison.Response{:status_code => 200, :body => body}} = HTTPoison.get(url, headers)
    {:ok, resp} = body |> Jason.decode()
    url = "http://tse.ir/json/HomePage/nazerMSG.json?#{epoch}"

    {:ok, %HTTPoison.Response{:status_code => 200, :body => body}} = HTTPoison.get(url, headers)
    {:ok, resp2} = body |> Jason.decode()

    {resp2, resp |> Map.get("tabs")}
  end

  @spec market_basic_info() :: map()
  def market_basic_info do
    data = tse_market()

    [volume, value, count, cap] =
      data |> elem(1) |> Enum.filter(fn x -> x["t"] == "cash" end) |> List.first() |> Map.get("v")

    %{"miniSlider" => [index, _volume, _trade_count, _cap, _, _]} = data |> elem(0)

    %Market{
      name: "main",
      index: index,
      volume: String.to_integer(volume) * 1_000_000,
      trade_count: count |> String.to_integer(),
      trade_value: value |> String.to_integer(),
      cap: cap |> String.to_integer()
    }
  end
end
