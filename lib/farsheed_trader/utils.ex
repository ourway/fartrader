defmodule FarTrader.Utils do
  @moduledoc false

  def get_timezone do
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

  def market_open? do
    n = now()
    wd = n |> Timex.weekday()
    n.hour <= 12 && n.minute <= 30 && (n.hour >= 9 && n.minute >= 0) && wd in [6, 7, 1, 2, 3]
  end

  @doc "sends http get using a default pool"
  def http_get(url, headers \\ [], cookies \\ []) do
    {:ok, resp} =
      HTTPoison.get(url, headers, hackney: [pool: :default, cookie: cookies, recv_timeout: 45_000])

    resp
  end

  @doc "sends http post using a default pool"
  def http_post(url, body \\ [], headers \\ [], cookies \\ []) do
    {:ok, resp} =
      HTTPoison.post(url, body, headers,
        hackney: [pool: :default, cookie: cookies, recv_timeout: 45_000]
      )

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
        rawlist |> Enum.map(fn x -> x |> elem(1) |> String.split(";") |> List.first() end)

      false ->
        rawlist
        |> Enum.map(fn x ->
          x
          |> elem(1)
          |> String.split(";")
          |> List.first()
          |> String.split("=")
          |> List.to_tuple()
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

  @doc """
    gets jdate like `1398/4/19' with shift in days
  """
  @spec get_jdate(integer()) :: binary() | map()
  def get_jdate(shift, mode \\ 0) do
    {:ok, result} =
      Jalaali.Calendar
      |> DateTime.utc_now()
      |> DateTime.convert!(Calendar.ISO)
      |> Timex.shift(days: shift)
      |> Timex.to_datetime("Asia/Tehran")
      |> DateTime.convert(Jalaali.Calendar)

    case mode do
      0 ->
        %DateTime{
          :day => jday,
          :month => jmonth,
          :year => jyear
        } = result

        "#{jyear}/#{jmonth}/#{jday}"

      1 ->
        result
    end
  end

  @doc " returns today as jdate "
  @spec get_jdate() :: binary()
  def get_jdate do
    get_jdate(0)
  end

  @doc """
  converts jalali datetime to utc datetime
    iex> FarTrader.Utils.jalali_to_datetime(1396, 4, 26, 19, 29, 0)
    ~U[2017-07-17 14:59:00Z]
  """
  def jalali_to_datetime(jyear, jmon, jday, hour, minute, second) do
    {:ok, jalaali_date} = Date.new(jyear, jmon, jday, Jalaali.Calendar)
    {:ok, iso_date} = Date.convert(jalaali_date, Calendar.ISO)

    Timex.to_datetime(
      {{iso_date.year, iso_date.month, iso_date.day}, {hour, minute, second}},
      "Asia/Tehran"
    )
    |> Timex.to_datetime("Etc/UTC")
  end
end
