defmodule SatOps.MixProject do
  use Mix.Project

  def project do
    [
      app: :sat_ops,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      listeners: [Phoenix.CodeReloader],
      releases: [
        sat_ops: [
          applications: [opentelemetry_exporter: :permanent, opentelemetry: :temporary]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {SatOps.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :public_key, :inets]
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "test.unit": :test,
        "test.integration": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.17"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:absinthe, "~> 1.12"},
      {:absinthe_plug, "~> 1.5"},
      {:dataloader, "~> 2.0"},
      {:oban, "~> 2.24"},
      {:req, "~> 0.5"},
      {:yaml_elixir, "~> 2.12"},
      {:ex_json_schema, "~> 0.11.5"},
      {:chumak, "~> 1.5"},
      {:argon2_elixir, "~> 4.1"},
      {:logger_json, "~> 7.0"},
      {:k8s, "~> 2.8"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.11"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_bandit, "~> 0.3.0"},
      {:stream_data, "~> 1.4", only: [:dev, :test]},
      {:mox, "~> 1.3", only: :test},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.unit": ["test --exclude integration --exclude bitcoin"],
      "test.integration": ["ecto.create --quiet", "ecto.migrate --quiet", "test --only integration"],
      lint: ["format --check-formatted", "credo --strict"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
