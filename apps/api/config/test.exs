import Config

config :sat_ops, SatOps.Repo,
  url:
    System.get_env("TEST_DATABASE_URL", "ecto://postgres:postgres@localhost:5435/satops_test") <>
      "#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2 + 4

config :sat_ops, SatOpsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-only-secret-key-base-000000000000000000000000000000000000000000000",
  server: false

config :sat_ops, Oban, testing: :manual

config :sat_ops,
  secret_key: Base.encode64(:binary.copy(<<2>>, 32)),
  start_integrations: false,
  config_schemas_dir: Path.expand("../../../packages/config-schemas/schemas", __DIR__),
  login_rate_limit: {100, 60_000}

config :argon2_elixir, t_cost: 1, m_cost: 8

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
