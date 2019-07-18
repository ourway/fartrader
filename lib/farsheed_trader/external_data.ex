defmodule FarTrader.ExternalData do
  @moduledoc false
  alias FarTrader.Market
  alias FarTrader.Utils
  alias FarTrader.Repo
  alias FarTrader.Stock
  # import Ecto.Query, only: [from: 2]

  def get_corp_info(stock) do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "http://tse.ir/json/Instrument/BasicInfo/BasicInfo_#{stock.isin}.html?updated=#{epoch}"
    %HTTPoison.Response{:status_code => 200, :body => body} = Utils.http_get(url)

    [
      _,
      _isin,
      _,
      corp_name,
      _,
      _fa_symbol,
      _,
      en_name,
      _,
      en_symbol,
      _,
      cisin,
      _,
      market_type,
      _,
      industry,
      _,
      industry_code,
      _,
      sub_industry,
      _,
      sub_industry_code
    ] =
      body
      |> Floki.parse()
      |> Floki.find("tr td")
      |> Enum.map(fn x -> x |> elem(2) |> List.last() end)

    stock
    |> Stock.changeset(%{
      en_name: en_name,
      cisin: cisin,
      en_symbol: en_symbol,
      market_type: market_type,
      industry: industry,
      sub_industry: sub_industry,
      industry_code: industry_code |> String.to_integer(),
      sub_industry_code: sub_industry_code |> String.to_integer(),
      corp_name: corp_name
    })
  end

  @doc """
    Get latest stock information from:
      `http://tse.ir/json/Instrument/info_IRO1ALMR0001.json`
  """
  @spec get_symbol_info(binary()) :: map()
  def get_symbol_info(isin) do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "http://tse.ir/json/Instrument/info_#{isin}.json?#{epoch}"

    case Utils.http_get(url, [{"Content-Type", "application/json"}]) do
      %HTTPoison.Response{:status_code => 404} ->
        {:error, :not_found}

      %HTTPoison.Response{:status_code => 200, :body => body} ->
        {:ok, data} = body |> Jason.decode()
        data
    end
  end

  @doc """
    converts tse.ir header time format to UTC datetime
  """
  @spec tse_time_to_jalali(binary()) :: map()
  def tse_time_to_jalali(str) do
    [jday, jmname, rem] = str |> String.split(" ")

    jmon =
      case jmname do
        "فروردین" -> 1
        "اردیبهشت" -> 2
        "خرداد" -> 3
        "تیر" -> 4
        "مرداد" -> 5
        "شهریور" -> 6
        "مهر" -> 7
        "آبان" -> 8
        "آذر" -> 9
        "دی" -> 10
        "بهمن" -> 11
        "اسفند" -> 12
      end

    [jyear, rem] = rem |> String.split("-")
    [hour, minute] = rem |> String.split(":")

    Utils.jalali_to_datetime(
      jyear |> String.to_integer(),
      jmon,
      jday |> String.to_integer(),
      hour |> String.to_integer(),
      minute |> String.to_integer(),
      0
    )
  end

  @doc """
    update stock data
  """
  @spec update_symbol_info(binary()) :: map()
  def update_symbol_info(isin) do
    data = isin |> get_symbol_info
    old_stock = Stock |> Repo.get_by(isin: isin)

    last_update_datetime =
      data |> Map.get("header") |> List.last() |> Map.get("time") |> tse_time_to_jalali

    #    case old_stock.day_latest_trade_local_datetime == data |> Map.get("tradeDate") do
    #      true ->
    #        :up_to_date
    #
    #      false ->
    #        {:ok, _stock} =
    #          old_stock
    #          |> Stock.changeset(%{
    #            depth: %{data: data |> Map.get("depths")},
    #            day_latest_trade_local_datetime: data |> Map.get("tradeDate"),
    #            yesterday_closing_price: data |> Map.get("yesterdayPrice"),
    #            day_closing_price: data |> Map.get("closingPrice"),
    #            day_last_traded_price: data |> Map.get("lastTradedPrice"),
    #            day_number_of_traded_shares: data |> Map.get("totalNumberOfTrades"),
    #            day_price_change_percent: data |> Map.get("priceVar"),
    #            day_price_change: data |> Map.get("priceChange"),
    #            day_closing_price_change_percent: data |> Map.get("closingPriceVarPercent"),
    #            day_closing_price_change: data |> Map.get("closingPriceChange"),
    #            day_low_price: data |> Map.get("lowPrice"),
    #            day_high_price: data |> Map.get("highPrice"),
    #            total_traded_value: data |> Map.get("totalTradeValue"),
    #            total_number_traded_shares: data |> Map.get("totalNumberOfSharesTraded"),
    #            day_min_allowed_price: data |> Map.get("lowAllowedPrice"),
    #            day_max_allowed_price: data |> Map.get("highAllowedPrice"),
    #            base_volume: data |> Map.get("basisVolume"),
    #            day_min_allowed_quantity: data |> Map.get("minQuantityOrder"),
    #            day_max_allowed_quantity: data |> Map.get("maxQuantityOrder"),
    #            day_best_ask: data |> Map.get("bestSellLimitPrice1"),
    #            day_best_bid: data |> Map.get("bestBuyLimitPrice1"),
    #            status:
    #              case data |> Map.get("symbolStateId") do
    #                5 ->
    #                  "banned"
    #
    #                1 ->
    #                  "active"
    #
    #                _ ->
    #                  "N/A"
    #              end,
    #            day_number_of_shares_bought_at_best_ask: data |> Map.get("bestBuyLimitQuantity1"),
    #            day_number_of_shares_sold_at_best_bid: data |> Map.get("bestSellLimitQuantity1")
    #          })
    #          |> Repo.update()
    #    end
  end

  @doc """
    fetches symbol history from tse.ir api.
    sample page is `http://tse.ir/json/Instrument/TradeHistory/TradeHistory_IRO1NIRO0001.html`
    example:
      
      iex> FarTrader.ExternalConnections.get_symbol_history("IRO1SIPA0001", 1398, 4)
  """
  @spec get_symbol_history(binary()) :: :not_found | list()
  def get_symbol_history(isin) do
    url =
      "http://tse.ir/json/Instrument/TradeHistory/TradeHistory_#{isin |> String.upcase()}.html"

    resp = Utils.http_get(url)

    case resp.status_code do
      200 ->
        resp.body |> Floki.parse() |> Floki.find("table tbody tr")

      _ ->
        :not_found
    end
  end

  def get_symbol_basic_info(isin) do
    stock = Stock |> Repo.get_by(isin: isin)
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "https://www.sahamyab.com/guest/twiter/symbolInfo?v=0.1&_=#{epoch}"

    {:ok, payload} =
      %{symbol: stock.fa_symbol, price: true, bestLimits: true, full: true} |> Jason.encode()

    %HTTPoison.Response{:status_code => 200, :body => body} =
      Utils.http_post(url, payload, [{"Content-Type", "application/json"}])

    body |> Jason.decode()
  end

  def update_stock_basic_info(stock) do
    {:ok, data} = stock.isin |> get_symbol_basic_info()

    {:ok, result} =
      stock
      |> Stock.changeset(%{
        ins_code: data["InsCode"],
        corp_name: data["corpName"],
        industry: data["sectionName"],
        sub_industry: data["subSectionName"],
        status: data["status"]
      })
      |> Repo.update()

    result
  end

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
