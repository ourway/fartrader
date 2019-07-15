defmodule FarTrader.Periodically do
  @moduledoc """
  Get's list of modules from config file and run it 
  based on config data:

  ```
    config :periodic,
  some_thing: [{FarTrader.ExternalConnections, :some_func,
                        [opt1, opt2]}, 3600],
  check_otherthing: [{FarTrader.DataCore, :some_func2,
                        [100]}, 1000]
  ```

  """
  use GenServer

  def start_link do
    {:ok, tasks} = Application.fetch_env(:farsheed_trader, __MODULE__)
    GenServer.start_link(__MODULE__, tasks)
  end

  def init(state) do
    # Schedule work to be performed at some point
    schedule_work(state, :init)
    {:ok, state}
  end

  def handle_info({:work, id, module, func, params}, state) do
    # IO.inspect {:running, id, module, func, params}
    Rihanna.enqueue({module, func, params})

    # Do the work you desire here

    # Reschedule once more
    schedule_work(state, id)
    {:noreply, state}
  end

  defp schedule_work(tasks, referer) do
    case referer do
      :init ->
        tasks
        |> Enum.map(fn t ->
          id = t |> elem(0)
          data = t |> elem(1)
          module = data |> elem(0)
          func = data |> elem(1)
          params = data |> elem(2)
          # timeout = data |> elem(3)
          # In 2 hours
          Process.send_after(self(), {:work, id, module, func, params}, 0)
        end)

      task ->
        tasks
        |> Enum.filter(fn t ->
          elem(t, 0) == task
        end)
        |> Enum.map(fn t ->
          # id = t |> elem(0)
          data = t |> elem(1)
          module = data |> elem(0)
          func = data |> elem(1)
          params = data |> elem(2)
          sleeptime = data |> elem(3)
          IO.inspect({:scedueling, task, sleeptime})
          Process.send_after(self(), {:work, task, module, func, params}, sleeptime)
        end)
    end
  end
end
