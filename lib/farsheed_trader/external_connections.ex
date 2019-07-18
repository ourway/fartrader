defmodule FarTrader.ExternalConnections do
  @moduledoc false
  alias FarTrader.Utils
  alias FarTrader.Repo
  alias FarTrader.Stock

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
end
