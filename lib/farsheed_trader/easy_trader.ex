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

  def update_stock_data(stock) do
    url = "https://easytrader.emofid.com/MarketData/GetTicker"
    {:ok, payload} = %{isin: stock.isin} |> Jason.encode()
    cookies = @master_account |> Auth.get_credentials()
    %HTTPoison.Response{:body => body} = url |> Utils.http_post(payload, @rest_headers, cookies)
    {:ok, %{"result" => true, "stock" => %{"stockData" => data}}} = body |> Jason.decode()

    {:ok, result} =
      stock
      |> Stock.changeset(%{
        base_volume: data["basisVolume"]
      })
      |> Repo.update()

    result
  end

  def get_stock_list do
    url = "https://easytrader.emofid.com/MarketData/GetTickers"
    {:ok, payload} = %{} |> Jason.encode()
    cookies = @master_account |> Auth.get_credentials()
    %HTTPoison.Response{:body => body} = url |> Utils.http_post(payload, @rest_headers, cookies)
    {:ok, stocks} = body |> Jason.decode()
    stocks
  end

  def add_stocks_to_db do
    list = get_stock_list()

    Repo.transaction(fn ->
      list
      |> Enum.map(fn s ->
        %Stock{
          isin: s["isin"],
          market_unit: s["marketUnit"],
          symbol: s["symbol"],
          fa_symbol: s["symbol"],
          name: s["title"],
          fa_name: s["title"]
        }
        |> Repo.insert(on_conflict: :nothing)
      end)
    end)
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
