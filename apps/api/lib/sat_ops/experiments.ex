defmodule SatOps.Experiments do
  import Ecto.Query
  alias SatOps.{Audit, Repo}
  alias SatOps.Experiments.{Action, AssertionResult, Run, RunState, Scenario, ScenarioSpec, Step}
  alias SatOps.Integrations.ConfigValidation

  def list_scenarios do
    latest = from s in Scenario, group_by: s.name, select: %{name: s.name, version: max(s.version)}

    Repo.all(
      from s in Scenario,
        join: l in subquery(latest),
        on: l.name == s.name and l.version == s.version,
        order_by: s.name
    )
  end

  def scenario_versions(name), do: Repo.all(from s in Scenario, where: s.name == ^name, order_by: [desc: s.version])
  def get_scenario(id), do: Repo.get(Scenario, id)

  def latest_scenario(name),
    do: Repo.one(from s in Scenario, where: s.name == ^name, order_by: [desc: s.version], limit: 1)

  def upsert_scenario(name, version, spec, yaml) do
    with :ok <- ScenarioSpec.validate(spec) |> to_result() do
      latest = latest_scenario(name)

      cond do
        latest && latest.spec == spec ->
          {:ok, latest}

        true ->
          version = max(version || 1, ((latest && latest.version) || 0) + 1)

          Repo.insert(%Scenario{
            name: name,
            version: version,
            title: spec["title"],
            description: spec["description"],
            guarantee: spec["guarantee"],
            required_capabilities: ScenarioSpec.required_capabilities(spec),
            spec: spec,
            source_yaml: yaml
          })
      end
    end
  end

  defp to_result(:ok), do: :ok
  defp to_result({:error, errors}), do: {:error, Enum.join(errors, "; ")}

  def start_run(environment_id, scenario_id, params, actor) do
    scenario = Repo.get!(Scenario, scenario_id)

    Repo.transaction(fn ->
      run =
        Repo.insert!(%Run{
          environment_id: environment_id,
          scenario_id: scenario.id,
          scenario_name: scenario.name,
          scenario_version: scenario.version,
          status: "created",
          seed: params["seed"] || :rand.uniform(2_147_483_647),
          params: Map.take(params, ["seed", "notes"]),
          correlation_id: Ecto.UUID.generate(),
          requested_by: actor && actor.id
        })

      scenario.spec["steps"]
      |> Enum.with_index()
      |> Enum.each(fn {s, i} ->
        Repo.insert!(%Step{
          run_id: run.id,
          position: i,
          step_key: s["id"],
          phase: s["phase"] || "run",
          action: s["action"],
          params: s["params"] || %{},
          max_attempts: s["maxAttempts"] || 1,
          timeout_ms: ConfigValidation.parse_duration(s["timeout"], 120_000) |> min(1_800_000)
        })
      end)

      %{run_id: run.id} |> SatOps.Experiments.Workers.StepWorker.new() |> Oban.insert!()

      Audit.record!(actor, "experiment.started",
        resource: run,
        changes: %{scenario: scenario.name, version: scenario.version}
      )

      run
    end)
  end

  def abort_run(%Run{} = run, actor) do
    if RunState.terminal?(run.status) do
      {:error, :already_finished}
    else
      Repo.transaction(fn ->
        updated = run |> Ecto.Changeset.change(params: Map.put(run.params, "abortRequested", true)) |> Repo.update!()
        Audit.record!(actor, "experiment.abort_requested", resource: run)
        %{run_id: run.id} |> SatOps.Experiments.Workers.StepWorker.new() |> Oban.insert()
        updated
      end)
    end
  end

  def list_runs(environment_id, opts \\ []) do
    Run
    |> where([r], r.environment_id == ^environment_id)
    |> then(fn q -> if s = opts[:statuses], do: where(q, [r], r.status in ^s), else: q end)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^min(opts[:limit] || 30, 200))
    |> Repo.all()
  end

  def get_run(id) do
    Repo.get(Run, id)
    |> Repo.preload(
      steps: from(s in Step, order_by: s.position),
      assertions: from(a in AssertionResult, order_by: a.position)
    )
  end

  def actions, do: Action.describe()

  def capabilities(environment_id), do: Action.runtime_capabilities(environment_id)
end
