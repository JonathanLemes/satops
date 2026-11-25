import Config

config :sat_ops, SatOps.Repo,
  url: System.get_env("DATABASE_URL", "ecto://postgres:postgres@localhost:5435/satops_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :sat_ops, SatOpsWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: false,
  secret_key_base: "dev-only-secret-key-base-0000000000000000000000000000000000000000000000",
  watchers: []

config :sat_ops,
  secret_key: Base.encode64(:binary.copy(<<1>>, 32)),
  dev_routes: true,
  config_schemas_dir: Path.expand("../../../packages/config-schemas/schemas", __DIR__)

config :logger, :default_formatter, format: "[$level] $metadata$message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
