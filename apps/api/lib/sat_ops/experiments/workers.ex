defmodule SatOps.Experiments.Workers.StepWorker do
  use Oban.Worker,
    queue: :experiments,
    max_attempts: 5,
    unique: [keys: [:run_id], states: [:available, :scheduled, :executing, :retryable], period: :infinity]

  alias SatOps.Experiments.Runner

  @impl true
  def timeout(_job), do: :timer.minutes(45)

  @impl true
  def perform(%Oban.Job{id: id, args: %{"run_id" => run_id}}) do
    owner = "#{node()}:job-#{id}"
    loop(run_id, owner, 0)
  end

  defp loop(run_id, owner, n) when n > 500, do: Runner.release_lease(run_id, owner) && {:snooze, 1}

  defp loop(run_id, owner, n) do
    case Runner.advance(run_id, owner) do
      :busy -> {:snooze, 15}
      {:done, _run} -> :ok
      {:continue, %{status: status}} when status in ["passed", "failed", "inconclusive", "aborted"] -> :ok
      {:continue, _run} -> loop(run_id, owner, n + 1)
    end
  end
end

defmodule SatOps.Experiments.Workers.RecoverStalled do
  use Oban.Worker, queue: :maintenance, max_attempts: 1
  import Ecto.Query
  alias SatOps.Repo
  alias SatOps.Experiments.{Run, RunState}

  @impl true
  def perform(_job) do
    now = DateTime.utc_now()
    stale = DateTime.add(now, -90, :second)

    Repo.all(
      from r in Run,
        where:
          r.status not in ^RunState.terminal() and (is_nil(r.lease_expires_at) or r.lease_expires_at < ^now) and
            r.updated_at < ^stale,
        select: r.id
    )
    |> Enum.each(fn id -> %{run_id: id} |> SatOps.Experiments.Workers.StepWorker.new() |> Oban.insert() end)

    :ok
  end
end
