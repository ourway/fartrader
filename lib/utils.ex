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
end
