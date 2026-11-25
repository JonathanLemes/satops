import Config

config :sat_ops,
  ecto_repos: [SatOps.Repo],
  generators: [timestamp_type: :utc_datetime_usec, binary_id: true],
  role: :all,
  runtime: :local,
  allowed_integration_hosts: ["127.0.0.1", "localhost", "bitcoin-0", "bitcoin-1", "demo-fintech"],
  allow_private_networks: true,
  cookie_secure: false,
  session_ttl_hours: 12,
  config_schemas_dir: nil

config :sat_ops, SatOps.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :sat_ops, SatOpsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: SatOpsWeb.ErrorJSON], layout: false],
  pubsub_server: SatOps.PubSub

config :sat_ops, Oban,
  engine: Oban.Engines.Basic,
  repo: SatOps.Repo,
  queues: [events: 5, ingestion: 5, ledger: 5, reconciliation: 2, experiments: 2, alerts: 3, maintenance: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 3600},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(10)},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", SatOps.Blockchain.Workers.PeriodicSync},
       {"* * * * *", SatOps.Experiments.Workers.RecoverStalled},
       {"*/5 * * * *", SatOps.Identity.Workers.PurgeSessions},
       {"* * * * *", SatOps.Configuration.Workers.Reconcile},
       {"* * * * *", SatOps.Reconciliation.Workers.Scheduler}
     ]}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :environment_id,
    :integration_id,
    :event_id,
    :operation_id,
    :experiment_id,
    :correlation_id,
    :causation_id
  ]

config :phoenix, :json_library, Jason

config :opentelemetry, traces_exporter: :none

import_config "#{config_env()}.exs"
