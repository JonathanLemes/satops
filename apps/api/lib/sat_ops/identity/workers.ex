defmodule SatOps.Identity.Workers.PurgeSessions do
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  @impl true
  def perform(_job) do
    SatOps.Identity.purge_expired_sessions()
    :ok
  end
end
