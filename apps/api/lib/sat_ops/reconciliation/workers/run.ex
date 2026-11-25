defmodule SatOps.Reconciliation.Workers.Run do
  use Oban.Worker, queue: :reconciliation, max_attempts: 1

  @impl true
  def timeout(_), do: :timer.minutes(5)

  @impl true
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    run = SatOps.Reconciliation.get_run(run_id)

    cond do
      is_nil(run) ->
        {:cancel, :not_found}

      run.status != "queued" ->
        :ok

      true ->
        SatOps.Integrations.Sync.sync_environment(run.environment_id)

        case SatOps.Reconciliation.execute(run_id) do
          {:ok, _} -> :ok
          {:error, reason} -> {:cancel, reason}
        end
    end
  end
end

defmodule SatOps.Reconciliation.Workers.Scheduler do
  use Oban.Worker, queue: :maintenance, max_attempts: 1
  import Ecto.Query
  alias SatOps.{Environments, Repo}
  alias SatOps.Reconciliation.Run

  @impl true
  def perform(_job) do
    for env <- Environments.list(:all), enabled?(env), due?(env) do
      SatOps.Reconciliation.enqueue(env.id, "scheduled")
    end

    :ok
  end

  defp enabled?(env), do: get_in(env.settings, ["reconciliation", "enabled"]) != false

  defp due?(env) do
    interval =
      SatOps.Integrations.ConfigValidation.parse_duration(get_in(env.settings, ["reconciliation", "interval"]), 300_000)

    last =
      Repo.one(
        from r in Run,
          where: r.environment_id == ^env.id,
          order_by: [desc: r.inserted_at],
          limit: 1,
          select: {r.inserted_at, r.status}
      )

    case last do
      nil -> true
      {_, status} when status in ["queued", "running"] -> false
      {at, _} -> DateTime.diff(DateTime.utc_now(), at, :millisecond) >= max(interval, 30_000)
    end
  end
end
