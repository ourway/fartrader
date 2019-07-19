defmodule FarTrader.ExternalData do
  @moduledoc false
  alias Ecto.Changeset
  alias FarTrader.Market
  alias FarTrader.Utils
  alias FarTrader.Repo
  alias FarTrader.Stock
  alias FarTrader.StockData
  # import Ecto.Query, only: [from: 2]
  #
  #
  @doc """
  		saves trade history to priv/historical folder for later analysis
  """
  def save_trade_history(stock) do
    basedir = :code.priv_dir(:farsheed_trader)

    savedir =
      "#{basedir}/historical_data/sahamyab.com/api/proxy/symbol/symbolCandleChartData/#{
        stock.isin
      }"

    File.mkdir(savedir)

    headers = [
      {"user-agent",
       "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36 OPR/62.0.3331.66"},
      {"accept", "application/json"}
    ]

    url =
      "https://www.sahamyab.com/api/proxy/symbol/symbolCandleChartData?namad=#{stock.fa_symbol}&type=all"
      |> URI.encode()

    case Utils.http_get(url, headers) do
      %HTTPoison.Response{:status_code => 200, :body => body} ->
        # {unixtime, first_traded_price, highest_price, lowest_price, last_traded_price, volume}
        rawfilepath = "#{savedir}/raw.json"
        :ok = File.write(rawfilepath, body)

      %HTTPoison.Response{:status_code => _} ->
        :error
    end
  end

  def get_price(stock) do
    xml = """
    <?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <GetSymbolPrice xmlns="http://tempuri.org/">
            <nscCode>#{stock.isin}</nscCode>
        </GetSymbolPrice>
    </soap:Body>
    </soap:Envelope>
    """

    headers = [{"Content-Type", "text/xml"}, {"SOAPAction", "http://tempuri.org/GetSymbolPrice"}]

    case Utils.http_post("http://tadbirrlc.com/WebService/WS_MobileV2.asmx", xml, headers) do
      %HTTPoison.Response{:status_code => 200, :body => body} ->
        doc = body |> Exml.parse()

        _is_negative = doc |> Exml.get("//IsNegative")
        _is_right = doc |> Exml.get("//IsRight")
        is_farabourse = doc |> Exml.get("//IsFaraBourse")
        _isin = doc |> Exml.get("//NscCode")
        last_traded_price = doc |> Exml.get("//LastTradedPrice")
        real_change_price = doc |> Exml.get("//RealChangePrice")
        mantissa = doc |> Exml.get("//Mantissa")
        closing_price = doc |> Exml.get("//ClosingPrice")
        high_allowed_price = doc |> Exml.get("//HighAllowedPrice")
        low_allowe_dprice = doc |> Exml.get("//LowAllowedPrice")
        price_var = doc |> Exml.get("//PriceVar")
        price_change = doc |> Exml.get("//PriceChange")
        total_number_ofshares_traded = doc |> Exml.get("//TotalNumberOfSharesTraded")

      %HTTPoison.Response{:status_code => _} ->
        :error
    end
  end

  def get_tsetmc_trade_history(stock) do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "http://www.tsetmc.com/tsev2/data/TradeDetail.aspx?i=#{stock.ins_code}&_=#{epoch}"

    case url |> Utils.http_get() do
      %HTTPoison.Response{:status_code => 200, :body => body} ->
        body
        |> :zlib.gunzip()
        |> Exml.parse()
        |> Exml.get("//row")
        |> Enum.map(fn h ->
          # [_, _, _, "09:00:40", _, "100000", _, "4200.00", _] = h
          [_, _, _, time, _, count, _, price, _] = h
          {time, count, price}
        end)

      %HTTPoison.Response{:status_code => _} ->
        :error
    end
  end

  def update_corp_info(stock) do
    case stock.market_unit in [
           #  "ETFFix",
           #  "MaskanFaraBourse",
           #  "ETFMixed",
           #  "BourseKalaGovahiSekkeh",
           #  "ETFStock",
           "Exchange"
           #  "ETFZaminSakhteman"
         ] do
      true ->
        stock |> tse_corp_info()

      false ->
        :continue
    end
  end

  def tse_corp_info(stock) do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    url = "http://tse.ir/json/Instrument/BasicInfo/BasicInfo_#{stock.isin}.html?updated=#{epoch}"

    case Utils.http_get(url) do
      %HTTPoison.Response{:status_code => 200, :body => body} ->
        try do
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

          {:ok, result} =
            stock
            |> Stock.changeset(%{
              en_name: en_name,
              cisin: cisin,
              en_symbol: en_symbol,
              market_type: market_type |> Persian.fix(),
              industry: industry |> Persian.fix(),
              sub_industry: sub_industry |> Persian.fix(),
              industry_code: industry_code |> String.to_integer(),
              sub_industry_code: sub_industry_code |> String.to_integer(),
              corp_name: corp_name |> Persian.fix()
            })
            |> Repo.update()

          result
        rescue
          MatchError ->
            stock
        end

      %HTTPoison.Response{:status_code => 404} ->
        :upstream_error
        stock
    end
  end

  @doc """
    Get latest stock information from:
      `http://tse.ir/json/Instrument/info_IRO1ALMR0001.json`
  """
  @spec get_tse_symbol_info(binary()) :: map()
  def get_tse_symbol_info(isin) do
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
    # data = isin |> get_symbol_info
    # old_stock = Stock |> Repo.get_by(isin: isin)

    # last_update_datetime =
    #  data |> Map.get("header") |> List.last() |> Map.get("time") |> tse_time_to_jalali

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

    jd =
      Regex.named_captures(
        ~r/(?<jyear>[\d]{4})\/(?<jmon>[\d]{2})\/(?<jday>[\d]{2})\s(?<hour>[\d]{2}):(?<minute>[\d]{2}):(?<second>[\d]{2})/,
        data["date"]
      )

    datetime =
      Utils.jalali_to_datetime(
        jd["jyear"] |> String.to_integer(),
        jd["jmon"] |> String.to_integer(),
        jd["jday"] |> String.to_integer(),
        jd["hour"] |> String.to_integer(),
        jd["minute"] |> String.to_integer(),
        jd["second"] |> String.to_integer()
      )

    record =
      %StockData{
        # important as it will lock to this
        latest_trade_datetime: datetime,
        latest_trade_local_datetime: data["date"],
        isin: stock.isin,
        trade_count: data["tradeCount"],
        # pe: data["PE"],
        min_allowed_volume: data["minAllowVolume"],
        # eps: data["estimatedEPS"],
        sell_volume_corp: data["sellVolumeCorp"],
        min_allowed_price: data["minAllowPrice"] * 1.0,
        sell_count_corp: data["sellCountCorp"],
        buy_count_corp: data["buyCountCorp"],
        max_price: data["maxPrice"] * 1.0,
        min_price: data["minPrice"] * 1.0,
        # sector_pe: data["sectorPE"],
        trade_total_price: data["tradeTotalPrice"] * 1.0,
        market_value: data["marketValue"] * 1.0,
        buy_volume_corp: data["buyVolumeCorp"],
        sell_count_ind: data["sellCountInd"],
        buy_volume_ind: data["buyVolumeInd"],
        max_allowed_volume: data["maxAllowVolume"],
        status: data["status"],
        trade_volume: data["tradeVolume"],
        max_allowed_price: data["maxAllowPrice"] * 1.0,
        stock_holders: data["stockholders"],
        first_traded_price: data["firstPrice"] * 1.0,
        closing_price: data["closingPrice"] * 1.0,
        yesterday_closing_price: data["yesterdayPrice"] * 1.0,
        min_price: data["minPrice"] * 1.0,
        queue_status: data["q_status"],
        best_limits: data["bestLimits"],
        sell_volume_ind: data["sellVolumeInd"],
        last_traded_price: data["lastPrice"] * 1.0,
        quantity: data["totalCount"],
        buy_count_ind: data["buyCountInd"]
      }
      |> StockData.changeset(%{})
      |> Changeset.put_assoc(:stock, stock)
      |> Repo.insert()

    {:ok, result} =
      stock
      |> Stock.changeset(%{
        ins_code: data["InsCode"],
        corp_name: data["corpName"] |> Persian.fix(),
        industry: data["sectionName"] |> Persian.fix(),
        sub_industry: data["subSectionName"] |> Persian.fix(),
        status: data["status"]
      })
      |> Repo.update()

    # result
    {data, record}
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

  def update_stock_stat_data(stock) do
    epoch = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    url =
      "https://www.sahamyab.com/api/proxy/symbol/getSymbolExtData?v=0.1&code=#{stock.fa_symbol}&stockWatch=1&_=#{
        epoch
      }"
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
