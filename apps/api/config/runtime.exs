import Config

if System.get_env("PHX_SERVER") do
  config :sat_ops, SatOpsWeb.Endpoint, server: true
end

if port = System.get_env("PORT") do
  config :sat_ops, SatOpsWeb.Endpoint, http: [port: String.to_integer(port)]
end

if config_env() == :prod do
  database_url = System.get_env("DATABASE_URL") || raise "DATABASE_URL is missing"
  secret_key_base = System.get_env("SECRET_KEY_BASE") || raise "SECRET_KEY_BASE is missing"
  secret_key = System.get_env("SATOPS_SECRET_KEY") || raise "SATOPS_SECRET_KEY is missing"

  config :sat_ops, SatOps.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  config :sat_ops, SatOpsWeb.Endpoint,
    url: [host: System.get_env("PHX_HOST", "localhost")],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    check_origin: false,
    secret_key_base: secret_key_base

  role =
    case System.get_env("SATOPS_ROLE", "all") do
      "api" -> :api
      "worker" -> :worker
      _ -> :all
    end

  config :sat_ops,
    role: role,
    secret_key: secret_key,
    runtime: if(System.get_env("SATOPS_RUNTIME") == "kubernetes", do: :kubernetes, else: :local),
    cookie_secure: System.get_env("SATOPS_COOKIE_SECURE", "false") == "true",
    bootstrap_secrets: System.get_env("SATOPS_BOOTSTRAP_SECRETS", ""),
    allowed_integration_hosts:
      System.get_env("SATOPS_ALLOWED_INTEGRATION_HOSTS", "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1),
    kubernetes_sandbox_namespaces:
      System.get_env("SATOPS_K8S_SANDBOX_NAMESPACES", "")
      |> String.split(",", trim: true)

  if role == :api do
    config :sat_ops, Oban, queues: false, plugins: false
  end

  if System.get_env("SATOPS_LOG_FORMAT", "json") == "json" do
    config :logger, :default_handler, formatter: {LoggerJSON.Formatters.Basic, metadata: :all}
  end

  if endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
    config :opentelemetry, traces_exporter: :otlp
    config :opentelemetry_exporter, otlp_protocol: :http_protobuf, otlp_endpoint: endpoint
  end
end
