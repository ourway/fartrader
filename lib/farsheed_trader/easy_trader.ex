defmodule EasyTrader.Auth do
  import Ecto.Query, only: [from: 2]
  alias FarTrader.BrokerCredentials
  alias FarTrader.Repo

  @moduledoc """
    Easy Trader Authentication process.
    this is the recepie:
      1- get a request verification token from a form input
      2- 
  """

  alias FarTrader.Utils
  @ua "Mozilla/5.0 (X11; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0"

  @doc """
  this will be the the request to procced, and will get a 
  `__RequestVerificationToken` from a hidden input form and will use
  in next request
  """

  def do_all(username, password) do
    # go and find the form
    form_url =
      "https://easytrader.emofid.com/"
      |> Utils.http_get()
      |> Utils.catch_redirected_location()

    form_page = form_url |> Utils.http_get()
    # find form rvt
    [{_, [_, _, {_, rvt}], []}] =
      form_page
      |> Map.get(:body)
      |> Floki.find("input[name=__RequestVerificationToken]")

    # get form page cookies
    form_data = "__RequestVerificationToken=#{rvt}&provider=Emofid" |> URI.encode()
    rvtcookie = form_page |> Utils.catch_cookies()
    ## we're gono send a post request to the following location
    nl = "https://easytrader.emofid.com/Account/ExternalLogin?ReturnUrl=/"
    # the following response will help us to redirect to next location
    r =
      nl
      |> Utils.http_post(
        form_data,
        [
          "Content-Type": "application/x-www-form-urlencoded",
          Host: nl |> URI.parse() |> Map.get(:host),
          "User-Agent": @ua,
          TE: "Trailers"
        ],
        rvtcookie
      )

    noncecookie = r |> Utils.catch_cookies()
    nl = r |> Utils.catch_redirected_location()

    # next request does not need any cookies
    r = nl |> Utils.http_get()
    nl = r |> Utils.catch_redirected_location()
    nc = r |> Utils.catch_cookies()
    # this is the login page that we'll send user and pass to it:
    resp = nl |> Utils.http_get([], nc)
    nc = resp |> Utils.catch_cookies()
    form = resp.body |> Floki.find("#primary_form")
    [return_url] = form |> Floki.find("input[name=ReturnUrl]") |> Floki.attribute("value")

    [rvf] =
      form |> Floki.find("input[name=__RequestVerificationToken]") |> Floki.attribute("value")

    data =
      """
      ReturnUrl=#{return_url}&Username=#{username}&Password=#{password}&button=login&RememberLogin=true&__RequestVerificationToken=#{
        rvf
      }&RememberLogin=false
      """
      |> URI.encode()

    # we'll send this request (which indeed is a main request to login) with
    # old cookies and also we're going to send it with the same location as
    # form
    # nl =
    r =
      nl
      |> Utils.http_post(
        data,
        [
          "Content-Type": "application/x-www-form-urlencoded",
          Host: nl |> URI.parse() |> Map.get(:host),
          "User-Agent": @ua,
          TE: "Trailers"
        ],
        nc
      )

    nl = "https://account.emofid.com" <> return_url
    nc2 = r |> Utils.catch_cookies()

    r =
      Utils.http_get(
        nl,
        [
          Host: nl |> URI.parse() |> Map.get(:host),
          "User-Agent": @ua,
          TE: "Trailers"
        ],
        nc ++ nc2
      )

    form = r.body |> Floki.find("form")
    [nl] = form |> Floki.attribute("action")

    [session_state] = form |> Floki.find("input[name=session_state]") |> Floki.attribute("value")

    [state] = form |> Floki.find("input[name=state]") |> Floki.attribute("value")
    [scope] = form |> Floki.find("input[name=scope]") |> Floki.attribute("value")
    [id_token] = form |> Floki.find("input[name=id_token]") |> Floki.attribute("value")
    [code] = form |> Floki.find("input[name=code]") |> Floki.attribute("value")

    data =
      "code=#{code}&id_token=#{id_token}&scope=#{scope}&state=#{state}&session_state=#{
        session_state
      }"
      |> URI.encode()

    nc = rvtcookie ++ noncecookie

    r =
      nl
      |> Utils.http_post(
        data,
        [
          "Content-Type": "application/x-www-form-urlencoded",
          Host: nl |> URI.parse() |> Map.get(:host),
          "User-Agent": @ua,
          TE: "Trailers"
        ],
        nc
      )

    ext_cookie = r |> Utils.catch_cookies()
    nl = "https://easytrader.emofid.com" <> (r |> Utils.catch_redirected_location())
    nc = rvtcookie ++ ext_cookie

    r =
      nl
      |> Utils.http_get(
        [
          Host: nl |> URI.parse() |> Map.get(:host),
          "User-Agent": @ua,
          TE: "Trailers"
        ],
        nc
      )

    app_cookie = r |> Utils.catch_cookies()

    rvtcookie ++ app_cookie

    ## get final app cookie
  end

  def test_successful_auth(cookies) do
    url = "https://easytrader.emofid.com/Order/GetOrders?_=" <> Ecto.UUID.generate()

    headers = [
      "Content-Type": "application/json"
    ]

    {:ok, payload} = %{page: 0, take: 1000} |> Jason.encode()

    Utils.http_post(url, payload, headers, cookies)
  end

  def get_credentials(nickname) do
    query =
      from bu in "broker_credentials",
        where: bu.nickname == ^nickname,
        where: bu.broker == "emofid",
        where: bu.credentials_expiration_datetime > ^Timex.now(),
        select: bu.credentials

    case query |> Repo.all() do
      [] ->
        nickname |> save_credentials
        nickname |> get_credentials

      [creds] ->
        creds |> Map.get("cookies")
    end
  end

  def get_all_credentials do
    BrokerCredentials
    |> Repo.all()
    |> Enum.map(fn bu ->
      bu.nickname |> save_credentials
      Process.sleep(5_000)

      schedule_next_crenentials_renewal()
    end)
  end

  def schedule_next_crenentials_renewal do
    Rihanna.schedule({EasyTrader, :get_all_credentials, []}, in: :timer.hours(4))
  end

  def save_credentials(nickname) do
    query =
      from bu in "broker_credentials",
        where: bu.nickname == ^nickname,
        where: bu.broker == "emofid",
        select: [:credentials_expiration_datetime, :credentials, :username, :password, :id]

    bu = query |> Repo.one()

    case bu.credentials_expiration_datetime > Timex.now() |> Timex.shift(hours: 1) do
      true ->
        :valid

      false ->
        creds = do_all(bu.username, bu.password)
        ext = Timex.now() |> Timex.shift(hours: 4)
        old = BrokerCredentials |> Repo.get!(bu.id)

        cs =
          Ecto.Changeset.change(old,
            credentials: %{cookies: creds},
            credentials_expiration_datetime: ext
          )

        case cs |> Repo.update() do
          {:ok, _} ->
            :updated

          {:error, _} ->
            :error
        end
    end
  end
end

defmodule EasyTrader.APIs do
  @moduledoc "Easy Trader REStful related apis"
  alias EasyTrader.Auth
  alias FarTrader.Repo
  alias FarTrader.Stock
  alias FarTrader.Utils
  @master_account "amir"

  @rest_headers [
    Host: "easytrader.emofid.com",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0",
    Accept: "application/json",
    "Content-Type": "application/json;charset=utf-8",
    Referer: "https://easytrader.emofid.com",
    TE: "Trailers"
  ]

  def update_stock_data(isin) do
    url = "https://easytrader.emofid.com/MarketData/GetTicker"
    {:ok, payload} = %{isin: isin} |> Jason.encode()
    cookies = @master_account |> Auth.get_credentials()
    %HTTPoison.Response{:body => body} = url |> Utils.http_post(payload, @rest_headers, cookies)

    case body |> Jason.decode() do
      {:ok, %{"result" => true, "stock" => %{"stockData" => data}}} ->
        old_stock = Stock |> Repo.get_by(isin: isin)

        case old_stock.day_latest_trade_local_datetime == data |> Map.get("tradeDate") do
          true ->
            :up_to_date

          false ->
            {:ok, _stock} =
              old_stock
              |> Stock.changeset(%{
                depth: %{data: data |> Map.get("depths")},
                day_latest_trade_local_datetime: data |> Map.get("tradeDate"),
                yesterday_closing_price: data |> Map.get("yesterdayPrice"),
                day_closing_price: data |> Map.get("closingPrice"),
                day_last_traded_price: data |> Map.get("lastTradedPrice"),
                day_number_of_traded_shares: data |> Map.get("totalNumberOfTrades"),
                day_price_change_percent: data |> Map.get("priceVar"),
                day_price_change: data |> Map.get("priceChange"),
                day_closing_price_change_percent: data |> Map.get("closingPriceVarPercent"),
                day_closing_price_change: data |> Map.get("closingPriceChange"),
                day_low_price: data |> Map.get("lowPrice"),
                day_high_price: data |> Map.get("highPrice"),
                total_traded_value: data |> Map.get("totalTradeValue"),
                total_number_traded_shares: data |> Map.get("totalNumberOfSharesTraded"),
                day_min_allowed_price: data |> Map.get("lowAllowedPrice"),
                day_max_allowed_price: data |> Map.get("highAllowedPrice"),
                base_volume: data |> Map.get("basisVolume"),
                day_min_allowed_quantity: data |> Map.get("minQuantityOrder"),
                day_max_allowed_quantity: data |> Map.get("maxQuantityOrder"),
                day_best_ask: data |> Map.get("bestSellLimitPrice1"),
                day_best_bid: data |> Map.get("bestBuyLimitPrice1"),
                status:
                  case data |> Map.get("symbolStateId") do
                    5 ->
                      "banned"

                    1 ->
                      "active"

                    _ ->
                      "N/A"
                  end,
                day_number_of_shares_bought_at_best_ask: data |> Map.get("bestBuyLimitQuantity1"),
                day_number_of_shares_sold_at_best_bid: data |> Map.get("bestSellLimitQuantity1")
              })
              |> Repo.update()
        end

      {:ok, %{"result" => false}} ->
        :update_failed
    end
  end

  def update_db_tickers do
    url = "https://easytrader.emofid.com/MarketData/GetTickers"
    {:ok, payload} = %{} |> Jason.encode()
    cookies = @master_account |> Auth.get_credentials()
    %HTTPoison.Response{:body => body} = url |> Utils.http_post(payload, @rest_headers, cookies)
    {:ok, stocks} = body |> Jason.decode()

    operations = fn ->
      stocks
      |> Enum.map(fn s ->
        Rihanna.schedule({EasyTrader.APIs, :update_stock_data, [s |> Map.get("isin")]},
          in: :timer.seconds(10)
        )

        stock = %Stock{
          isin: s |> Map.get("isin"),
          symbol: s |> Map.get("symbol") |> Persian.fix(),
          fa_symbol: s |> Map.get("symbol") |> Persian.fix(),
          market_unit: s |> Map.get("marketUnit")
        }

        case Stock |> Repo.get_by(isin: stock.isin) do
          nil ->
            {:ok, _} = stock |> Repo.insert()

          old_stock ->
            {:ok, _} =
              old_stock
              |> Stock.changeset(%{
                symbol: stock.symbol,
                fa_symbol: stock.fa_symbol,
                market_unit: stock.market_unit
              })
              |> Repo.update()
        end
      end)
    end

    Repo.transaction(operations)
  end

  def get_orders(cookies) do
    url = "https://easytrader.emofid.com/Order/GetOrders"
    {:ok, payload} = %{page: 0, take: 50} |> Jason.encode()
    resp = Utils.http_post(url, payload, @rest_headers, cookies)
    {:ok, results} = resp.body |> Jason.decode()
    results
  end

  def search_orders(cookies) do
    url = "https://easytrader.emofid.com/OrdersList/Search"

    {:ok, payload} =
      %{
        options: %{
          "filter" => [
            ["OrderEntryDate", ">=", "2019/6/8 0:0:0"],
            "and",
            ["OrderEntryDate", "<=", "2019/7/9 23:59:0"],
            "and",
            ["SymbolISIN", "=", "IRO3IGCZ0001"]
          ],
          "requireTotalCount" => true,
          "searchOperation" => "contains",
          "searchValue" => nil,
          "skip" => 0,
          "sort" => [%{"desc" => true, "selector" => "OrderEntryDate"}],
          "take" => 20,
          "userData" => %{}
        }
      }
      |> Jason.encode()

    Utils.http_post(url, payload, @rest_headers, cookies)
  end
end
