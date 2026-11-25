defmodule SatOps.Observability do
  def setup do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:sat_ops, :repo])
    :ok
  end
end

defmodule SatOps.Observability.Metrics do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [
      {TelemetryMetricsPrometheus.Core, metrics: metrics(), name: :satops_prometheus},
      {:telemetry_poller, measurements: periodic(), period: 15_000, name: :satops_poller}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def scrape, do: TelemetryMetricsPrometheus.Core.scrape(:satops_prometheus)

  @sec {:native, :second}

  def metrics do
    [
      last_value("chain_ingestion_lag_blocks", event_name: [:sat_ops, :chain, :lag], measurement: :blocks),
      counter("chain_reorganizations_total", event_name: [:sat_ops, :chain, :reorganization], measurement: :count),
      sum("zmq_sequence_gaps_total", event_name: [:sat_ops, :zmq, :gap], measurement: :count),
      distribution("bitcoin_rpc_duration_seconds",
        event_name: [:sat_ops, :bitcoin, :rpc],
        measurement: :duration,
        unit: @sec,
        tags: [:method],
        reporter_options: [buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]]
      ),
      sum("integration_reconnects_total",
        event_name: [:sat_ops, :integration, :reconnect],
        measurement: :count,
        tags: [:kind]
      ),
      distribution("ledger_posting_duration_seconds",
        event_name: [:sat_ops, :ledger, :posting],
        measurement: :duration,
        unit: @sec,
        reporter_options: [buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 1]]
      ),
      sum("ledger_invariant_violations_total",
        event_name: [:sat_ops, :ledger, :invariant_violation],
        measurement: :count,
        tags: [:kind]
      ),
      counter("reconciliation_runs_total",
        event_name: [:sat_ops, :reconciliation, :run],
        measurement: :count,
        tags: [:status]
      ),
      last_value("reconciliation_discrepancies",
        event_name: [:sat_ops, :reconciliation, :run],
        measurement: :open_discrepancies
      ),
      last_value("job_queue_depth", event_name: [:sat_ops, :oban, :queue], measurement: :depth, tags: [:queue]),
      counter("job_failures_total", event_name: [:oban, :job, :exception], tags: [:queue]),
      distribution("experiment_duration_seconds",
        event_name: [:sat_ops, :experiment, :finished],
        measurement: :duration,
        unit: @sec,
        tags: [:status],
        reporter_options: [buckets: [1, 5, 15, 30, 60, 120, 300, 600]]
      ),
      sum("experiment_assertions_failed_total",
        event_name: [:sat_ops, :experiment, :finished],
        measurement: :failed_assertions
      ),
      distribution("http_request_duration_seconds",
        event_name: [:phoenix, :endpoint, :stop],
        measurement: :duration,
        unit: @sec,
        tags: [:method],
        tag_values: &%{method: &1.conn.method},
        reporter_options: [buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5]]
      ),
      last_value("vm_memory_total_bytes", event_name: [:vm, :memory], measurement: :total),
      last_value("vm_run_queue_total", event_name: [:vm, :total_run_queue_lengths], measurement: :total)
    ]
  end

  defp periodic, do: [{__MODULE__, :emit_queue_depth, []}]

  def emit_queue_depth do
    %{rows: rows} =
      SatOps.Repo.query!(
        "SELECT queue, count(*) FROM oban_jobs WHERE state IN ('available','scheduled','retryable') GROUP BY queue"
      )

    Enum.each(rows, fn [queue, depth] ->
      :telemetry.execute([:sat_ops, :oban, :queue], %{depth: depth}, %{queue: queue})
    end)
  rescue
    _ -> :ok
  end
end
