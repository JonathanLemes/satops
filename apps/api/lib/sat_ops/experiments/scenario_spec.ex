defmodule SatOps.Experiments.ScenarioSpec do
  alias SatOps.Experiments.{Action, Assertions}

  def validate(spec) when is_map(spec) do
    steps = spec["steps"] || []
    registry = Action.registry()

    step_errors =
      steps
      |> Enum.with_index()
      |> Enum.flat_map(fn {step, i} ->
        case Map.fetch(registry, step["action"]) do
          :error ->
            ["steps[#{i}] (#{step["id"]}): action #{step["action"]} is not in the action whitelist"]

          {:ok, mod} ->
            case mod.validate(step["params"] || %{}) do
              :ok -> []
              {:error, msg} -> ["steps[#{i}] (#{step["id"]}): #{msg}"]
            end
        end
      end)

    dupes =
      steps
      |> Enum.map(& &1["id"])
      |> Enum.frequencies()
      |> Enum.filter(fn {_, n} -> n > 1 end)
      |> Enum.map(fn {id, _} -> "step id #{id} is used more than once" end)

    assertion_errors =
      (spec["assertions"] || [])
      |> Enum.with_index()
      |> Enum.flat_map(fn {a, i} ->
        case Assertions.validate(a) do
          :ok -> []
          {:error, msg} -> ["assertions[#{i}]: #{msg}"]
        end
      end)

    case step_errors ++ dupes ++ assertion_errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  def validate(_), do: {:error, ["spec must be a mapping"]}

  def required_capabilities(spec) do
    registry = Action.registry()

    from_steps =
      (spec["steps"] || [])
      |> Enum.flat_map(fn s ->
        case Map.fetch(registry, s["action"]) do
          {:ok, mod} -> mod.capabilities()
          :error -> []
        end
      end)

    Enum.uniq((spec["requiredCapabilities"] || []) ++ from_steps)
  end
end
