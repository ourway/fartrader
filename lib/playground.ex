defmodule FarTrader.Playground do
  @defmodule false

  def maybe_crash do
    crash_factor = :rand.uniform(100)
    IO.puts("Crash factor: #{crash_factor}")
    if crash_factor > 60, do: raise("oh no! going down!")
  end
end
