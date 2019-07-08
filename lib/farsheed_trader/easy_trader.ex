defmodule EasyTrader.Auth do
  @moduledoc """
    Easy Trader Authentication process.
    this is the recepie:
      1- get a request verification token from a form input
      2- 
  """

  @rest_headers [
      Host: "easytrader.emofid.com",
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0",
      Accept: "application/json",
      "Content-Type": "application/json;charset=utf-8",
      Referer: "https://easytrader.emofid.com",
      TE: "Trailers"
    ]
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

    {:ok, payload} = %{page: 0, take: 50} |> Jason.encode()

    Utils.http_post(url, payload, headers, cookies)
  end

  def get_orders(cookies) do
    url = "https://easytrader.emofid.com/Order/GetOrders"
    {:ok, payload} = %{page: 0, take: 50} |> Jason.encode()
    Utils.http_post(url, payload, @rest_headers, cookies)
  end


  def search_orders(cookies) do
    url = "https://easytrader.emofid.com/OrdersList/Search"


    {:ok, payload} = %{
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
    } |> Jason.encode


    Utils.http_post(url, payload, @rest_headers, cookies)
  end



end
