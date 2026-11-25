defmodule SatOps.Seeds do
  require Logger
  alias SatOps.{Configuration, Dashboards}

  def ensure_platform_defaults(_env) do
    Dashboards.ensure_defaults()
    load_scenarios()
    :ok
  end

  def scenarios_dir do
    case Application.get_env(:sat_ops, :scenarios_dir) do
      nil -> Application.app_dir(:sat_ops, "priv/scenarios")
      path -> path
    end
  end

  def load_scenarios do
    dir = scenarios_dir()

    if File.dir?(dir) do
      for file <- Path.wildcard(Path.join(dir, "*.yaml")) do
        case Configuration.apply_yaml(File.read!(file), actor: nil, message: "bundled scenario") do
          {:ok, _} -> :ok
          {:error, reason} -> Logger.warning("bundled scenario #{Path.basename(file)} rejected: #{inspect(reason)}")
        end
      end
    end

    :ok
  end
end
