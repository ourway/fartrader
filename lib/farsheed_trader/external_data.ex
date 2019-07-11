defmodule FarTrader.ExternalData do
  @moduledoc false
  alias FarTrader.Market

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
    url = "http://tse.ir/json/HomePage/nazerMSG.json?_=#{epoch}"

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

  @spec market_basic_info() :: map()
  def market_basic_info do
    %{"miniSlider" => [index, volume, trade_count, cap, _, _]} = tse_market()

    %Market{
      name: "main",
      index: index,
      volume: volume * 1_000_000,
      trade_count: trade_count,
      cap: cap
    }
  end
end
