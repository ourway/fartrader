defmodule EasyTrader.Auth do
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
    nl = "https://easytrader.emofid.com" <> (r |> Utils.catch_redirected_location)
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

  def get_form_token do
    base_url = "https://easytrader.emofid.com"
    postfix_url = "/Account/Login?ReturnUrl=%2Forder"
    resp = Utils.http_get(base_url <> postfix_url)
    # catch raw cookies to use for next
    cookies = Utils.catch_cookies(resp, true)

    [{_, [_, _, {_, rvt}], []}] =
      resp.body |> Floki.find("input[name=__RequestVerificationToken]")

    [next_location] = resp.body |> Floki.find("form") |> Floki.attribute("action")

    loc =
      case URI.parse(next_location) |> Map.get(:host) do
        nil ->
          base_url <> next_location

        _ ->
          next_location
      end

    {loc, rvt, cookies}
  end

  @doc "gets login url and required cookies to procced authentication"
  def get_login_info do
    {loc, rvt, cookies} = get_form_token()
    # Now post with cookies:
    headers = [
      "Content-Type": "application/x-www-form-urlencoded"
    ]

    formdata = "__RequestVerificationToken=#{rvt}&provider=Emofid"
    resp = Utils.http_post(loc, URI.encode(formdata), headers, cookies)
    loc = resp |> Utils.catch_redirected_location()
    cookies = resp |> Utils.catch_cookies()
    {loc, cookies}
  end

  def get_login_page_url do
    {loc, cookies} = get_login_info()
    resp = Utils.http_get(loc, [], cookies)

    next_location = resp |> Utils.catch_redirected_location()
    next_base_url = "https://account.emofid.com"

    loc =
      case URI.parse(next_location) |> Map.get(:host) do
        nil ->
          next_base_url <> next_location

        _ ->
          next_location
      end

    loc
  end

  def get_login_page do
    loc = get_login_page_url()
    resp = Utils.http_get(loc)
    cookies = resp |> Utils.catch_cookies()
    form = resp.body |> Floki.find("#primary_form")
    [return_url] = form |> Floki.find("input[name=ReturnUrl]") |> Floki.attribute("value")

    [rvf] =
      form |> Floki.find("input[name=__RequestVerificationToken]") |> Floki.attribute("value")

    loc =
      case URI.parse(return_url) |> Map.get(:host) do
        nil ->
          "https://account.emofid.com/Login?returnUrl" <> return_url

        _ ->
          return_url
      end

    {loc, rvf, cookies}
  end

  def get_auth_callback(username, password) do
    {return_url, rvf, cookies} = get_login_page()

    headers = [
      "Content-Type": "application/x-www-form-urlencoded"
    ]

    raw_data = """
    ReturnUrl=#{return_url}&Username=#{username}&Password=#{password}&button=login&RememberLogin=true&__RequestVerificationToken=#{
      rvf
    }&RememberLogin=false
    """

    data = URI.encode(raw_data)

    resp = Utils.http_post(return_url, data, headers, cookies)

    case resp.status_code do
      200 ->
        {403, :not_authorized}

      302 ->
        next_loc = "https://account.emofid.com" <> (resp |> Utils.catch_redirected_location())
        next_cookies = cookies ++ (resp |> Utils.catch_cookies())
        {next_loc, next_cookies}
    end
  end

  def get_auth(username, password) do
    case get_auth_callback(username, password) do
      {403, _error} ->
        {:error, :problem}

      {url, cookies} ->
        resp = Utils.http_post(url, [], [], cookies)
        cookies2 = cookies ++ (resp |> Utils.catch_cookies())
        next_loc = resp |> Utils.catch_redirected_location()
        {"https://account.emofid.com" <> next_loc, cookies2}
    end
  end

  def get_signin_oidc(username, password) do
    case get_auth(username, password) do
      {:error, :problem} ->
        :error

      {url, cookies} ->
        resp = Utils.http_get(url, [], cookies)
        next_loc = resp |> Utils.catch_redirected_location()
        resp = Utils.http_get(next_loc, [], cookies)
        next_loc = resp |> Utils.catch_redirected_location()
        cookies2 = cookies ++ (resp |> Utils.catch_cookies())
        resp = Utils.http_get(next_loc, [], cookies)
        form = resp.body |> Floki.find("form")
        [next_location] = form |> Floki.attribute("action")

        [session_state] =
          form |> Floki.find("input[name=session_state]") |> Floki.attribute("value")

        [state] = form |> Floki.find("input[name=state]") |> Floki.attribute("value")
        [scope] = form |> Floki.find("input[name=scope]") |> Floki.attribute("value")
        [id_token] = form |> Floki.find("input[name=id_token]") |> Floki.attribute("value")
        [code] = form |> Floki.find("input[name=code]") |> Floki.attribute("value")

        raw_data =
          "code=#{code}&id_token=#{id_token}&scope=#{scope}&state=#{state}&session_state=#{
            session_state
          }"

        data = URI.encode(raw_data)

        headers = [
          "Content-Type": "application/x-www-form-urlencoded"
        ]

        resp = Utils.http_post(next_location, data, headers, cookies2)
    end
  end

  def get_auth_cookies do
    username = "0063879794"
    password = "TR4Fh*q^57bYgRojIN$4UdNn#25GY6n4G7cYjYqprR39ws%7"
    do_all(username, password)
    # password = "wrong"
    #
  end

  def test_successful_auth(cookies) do
    url = "https://easytrader.emofid.com/Order/GetOrders?_=" <> Ecto.UUID.generate()

    headers = [
      "Content-Type": "application/json"
    ]

    {:ok, payload} = %{page: 0, take: 50} |> Jason.encode()

    Utils.http_post(url, payload, headers, cookies)
  end
end
