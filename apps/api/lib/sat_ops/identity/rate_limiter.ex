defmodule SatOps.Identity.RateLimiter do
  use GenServer

  @table __MODULE__

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def hit(bucket, limit, window_ms) do
    now = System.monotonic_time(:millisecond)
    window = div(now, window_ms)
    key = {bucket, window}
    count = :ets.update_counter(@table, key, {2, 1}, {key, 0, now + window_ms})
    if count <= limit, do: :ok, else: {:error, :rate_limited}
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule()
    {:noreply, state}
  end

  defp schedule, do: Process.send_after(self(), :sweep, 60_000)
end
