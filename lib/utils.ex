defmodule FarTrader.Utils do
  @moduledoc false

  def get_timezone() do
    {zone, result} = System.cmd("date", ["+%Z"])
    if result == 0, do: String.trim(zone)
  end

  def get_time_shift do
    timezone = get_timezone()

    %{"dir" => dir, "hours" => hours, "minutes" => minutes} =
      Regex.named_captures(~r/(?<dir>[+=])(?<hours>[\d]{2})(?<minutes>[\d]{2})/, timezone)

    multiple =
      case dir do
        "+" ->
          1

        "-" ->
          -1
      end

    multiple * ((hours |> String.to_integer()) * 3600 + (minutes |> String.to_integer()) * 60)
  end

  def now do
    # timeshift = get_time_shift()
    # DateTime.utc_now |> DateTime.add(timeshift)
    Timex.now("Asia/Tehran")
  end

  def is_market_open? do
    n = now()
    wd = n |> Timex.weekday()
    n.hour <= 12 && n.minute <= 30 && (n.hour >= 9 && n.minute >= 0) && wd in [6, 7, 1, 2, 3]
  end


  @doc "sends http get using a default pool"
  def http_get(url, headers \\ [], cookies \\ []) do
    {:ok, resp} = HTTPoison.get(url, headers, hackney: [pool: :auth_pool, cookie: cookies])
    resp
  end


  @doc "sends http post using a default pool"
  def http_post(url, body \\ [], headers \\ [], cookies \\ []) do
    {:ok, resp} = HTTPoison.post(url, body, headers, hackney: [pool: :auth_pool, cookie: cookies])
    resp
  end

  @doc "catches Set-Cookie values as list of tuples "
  @spec catch_cookies(map()) :: list()
  def catch_cookies(resp, raw \\ true) do
    rawlist =
      resp.headers
      |> Enum.filter(fn x -> elem(x, 0) == "Set-Cookie" end)

    case raw do
      true ->
        rawlist |> Enum.map(fn x -> x |> elem(1) end)

      false ->
        rawlist
        |> Enum.map(fn x ->
          elem(x, 1) |> String.split(";") |> List.first() |> String.split("=") |> List.to_tuple()
        end)
    end
  end

  @doc "catches Location header value in case of redirection"
  @spec catch_redirected_location(map()) :: binary()
  def catch_redirected_location(resp) do
    case resp.status_code do
      302 ->
        resp.headers
        |> Enum.filter(fn x -> elem(x, 0) == "Location" end)
        |> List.last()
        |> elem(1)

      _ ->
        nil
    end
  end
end
