defmodule FarTrader.Tasks do
  @moduledoc false
  @timezone "Asia/Tehran"

  @doc """
    schedule({module, fun, args}, {{year, month, day}, {hour, minute, second}})

    schedule a task to run on a specefic datatime

        iex> FarTrader.Tasks.schedule({Tasks, :test_me, []}, {{2019, 8, 7}, {20, 39, 05}} )
  """
  def schedule({module, fun, args}, {{year, month, day}, {hour, minute, second}}) do
    d =
      {{year, month, day}, {hour, minute, second}}
      |> Timex.to_datetime(@timezone)
      |> Timex.to_datetime("Etc/UTC")

    Rihanna.schedule({module, fun, args}, at: d)
  end

  def test_me do
    Task.async(fn ->
      System.cmd("notify-send", ["Trader Schedule", "I am working"])
    end)
  end
end
