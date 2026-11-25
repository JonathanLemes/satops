defmodule SatOps.Blockchain.Workers.PeriodicSync do
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query
  alias SatOps.Repo
  alias SatOps.Blockchain.Workers.SyncChain

  @impl true
  def perform(_job) do
    Repo.all(
      from i in SatOps.Integrations.Integration,
        where: i.kind == "bitcoin_core" and i.enabled,
        distinct: true,
        select: i.environment_id
    )
    |> Enum.each(&SyncChain.enqueue(&1, "periodic"))

    :ok
  end
end
