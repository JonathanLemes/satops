defmodule SatOps.Blockchain.Workers.SyncChain do
  use Oban.Worker,
    queue: :ingestion,
    max_attempts: 10,
    unique: [keys: [:environment_id], states: [:available, :scheduled, :retryable], period: :infinity]

  require Logger
  alias SatOps.{Blockchain, Environments, Integrations}
  alias SatOps.Blockchain.ChainSync
  alias SatOps.Integrations.Adapters.BitcoinCore

  def enqueue(environment_id, reason) do
    %{environment_id: environment_id, reason: reason} |> new() |> Oban.insert()
  end

  @impl true
  def backoff(%Oban.Job{attempt: attempt}),
    do: div(SatOps.Backoff.delay(attempt, base_ms: 2_000, max_ms: 120_000), 1000)

  @impl true
  def timeout(_job), do: :timer.minutes(5)

  @impl true
  def perform(%Oban.Job{args: %{"environment_id" => env_id}}) do
    Logger.metadata(environment_id: env_id)

    with %{} = env <- Environments.get(env_id),
         {:ok, integration} <- Blockchain.reference_node(env_id),
         {:ok, creds} <- Integrations.credentials(integration) do
      rpc = BitcoinCore.rpc(integration, creds)
      started = System.monotonic_time()

      case ChainSync.run(env, rpc) do
        {:ok, result} ->
          :telemetry.execute(
            [:sat_ops, :chain, :sync],
            %{duration: System.monotonic_time() - started, blocks: length(result.connected)},
            %{
              environment_id: env_id
            }
          )

          Integrations.touch_sync(integration.id, %{"tipHash" => result.tip_hash, "tipHeight" => result.tip_height})
          Blockchain.record_lag(env_id, integration)
          unless result.caught_up, do: enqueue_now(env_id)
          :ok

        {:error, :local_tip_changed} ->
          enqueue_now(env_id)
          :ok

        {:error, {:unsafe_network, chain}} ->
          {:cancel, "refusing to ingest non-regtest chain #{chain}"}

        {:error, reason} ->
          {:error, Integrations.format_error(reason)}
      end
    else
      nil -> {:cancel, :environment_not_found}
      {:error, :no_reachable_node} -> {:snooze, 30}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp enqueue_now(env_id) do
    %{environment_id: env_id, reason: "continue"} |> new(schedule_in: 1) |> Oban.insert()
  end
end
