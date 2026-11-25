defmodule SatOps.Seeds do
  require Logger
  alias SatOps.{Configuration, Dashboards}

  def ensure_platform_defaults(_env) do
    Dashboards.ensure_defaults()
    load_bootstrap()
    load_scenarios()
    :ok
  end

  def bootstrap_dir do
    case Application.get_env(:sat_ops, :bootstrap_dir) do
      nil -> Application.app_dir(:sat_ops, "priv/bootstrap")
      path -> path
    end
  end

  def load_bootstrap do
    dir = bootstrap_dir()

    if File.dir?(dir) do
      for file <- dir |> Path.join("*.yaml") |> Path.wildcard() |> Enum.sort() do
        with {:ok, doc} <- SatOps.Configuration.Yaml.parse(File.read!(file)),
             nil <- Configuration.get(doc["kind"], get_in(doc, ["metadata", "name"])) do
          case Configuration.apply_document(doc, actor: nil, message: "bootstrap") do
            {:ok, _} -> :ok
            {:error, reason} -> Logger.warning("bootstrap resource #{Path.basename(file)} rejected: #{inspect(reason)}")
          end
        else
          _ -> :ok
        end
      end
    end

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
