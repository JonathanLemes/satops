defmodule SatOps.Experiments.Runner do
  import Ecto.Query
  require Logger
  alias SatOps.{Environments, Events, Repo}

  alias SatOps.Experiments.{
    Action,
    AssertionResult,
    Assertions,
    Context,
    Report,
    Run,
    RunState,
    Scenario,
    ScenarioSpec,
    Step
  }

  @lease_slack_ms 30_000

  def advance(run_id, owner) do
    case acquire_lease(run_id, owner) do
      nil -> :busy
      run -> do_advance(run, owner)
    end
  end

  defp acquire_lease(run_id, owner) do
    now = DateTime.utc_now()

    {count, rows} =
      from(r in Run,
        where: r.id == ^run_id and (is_nil(r.lease_expires_at) or r.lease_expires_at < ^now or r.lease_owner == ^owner),
        where: r.status not in ^RunState.terminal(),
        select: r
      )
      |> Repo.update_all(set: [lease_owner: owner, lease_expires_at: DateTime.add(now, 60, :second)])

    if count == 1, do: hd(rows), else: nil
  end

  defp extend_lease(run, owner, ms) do
    from(r in Run, where: r.id == ^run.id and r.lease_owner == ^owner)
    |> Repo.update_all(set: [lease_expires_at: DateTime.add(DateTime.utc_now(), ms + @lease_slack_ms, :millisecond)])
  end

  def release_lease(run_id, owner) do
    from(r in Run, where: r.id == ^run_id and r.lease_owner == ^owner)
    |> Repo.update_all(set: [lease_owner: nil, lease_expires_at: nil])
  end

  defp do_advance(%Run{status: "created"} = run, _owner) do
    {:continue, move(run, "validating")}
  end

  defp do_advance(%Run{status: "validating"} = run, _owner) do
    scenario = Repo.get!(Scenario, run.scenario_id)
    env = Environments.get!(run.environment_id)
    available = Action.runtime_capabilities(env.id)
    missing = ScenarioSpec.required_capabilities(scenario.spec) -- available

    cond do
      run.params["abortRequested"] ->
        {:continue, finalize(run, "aborted", "aborted before start")}

      (errors = ScenarioSpec.validate(scenario.spec)) != :ok ->
        {:error, msg} = errors
        {:continue, finalize(run, "failed", "scenario is invalid: #{Enum.join(msg, "; ")}")}

      missing != [] ->
        {:continue,
         finalize(
           run,
           "failed",
           "runtime does not provide required capabilities: #{Enum.join(missing, ", ")}. Actions are never simulated when their runtime is unavailable."
         )}

      true ->
        {:continue, move(run, "provisioning")}
    end
  end

  defp do_advance(%Run{status: "provisioning"} = run, _owner) do
    case SatOps.Blockchain.reference_node(run.environment_id) do
      {:ok, _} ->
        {:continue, move(run, "preparing")}

      {:error, :no_reachable_node} ->
        if needs_bitcoin?(run) do
          {:continue, finalize(run, "inconclusive", "no reachable Bitcoin node to provision the experiment")}
        else
          {:continue, move(run, "preparing")}
        end
    end
  end

  defp do_advance(run, owner) do
    steps = steps(run.id)

    cond do
      Enum.any?(steps, &(&1.status == "running")) ->
        recover_running(run, Enum.find(steps, &(&1.status == "running")))

      run.params["abortRequested"] && run.status != "cleaning_up" ->
        skip_remaining(run.id, ["prepare", "run", "verify"], "aborted")
        {:continue, move(run, "cleaning_up")}

      run.status != "cleaning_up" and Enum.any?(steps, &(&1.status in ["failed", "unknown"] and &1.phase != "cleanup")) ->
        skip_remaining(run.id, ["prepare", "run", "verify"], "previous step failed")
        {:continue, move(run, "cleaning_up")}

      next = next_step(steps, run.status) ->
        target = RunState.phase_status(next.phase)
        run = if target != run.status, do: move(run, target), else: run
        execute_step(run, next, owner)

      run.status in ["preparing", "running"] ->
        {:continue, move(run, "verifying")}

      run.status == "verifying" ->
        evaluate_assertions(run, owner)
        {:continue, move(run, "cleaning_up")}

      run.status == "cleaning_up" ->
        complete(run)
    end
  end

  defp needs_bitcoin?(run) do
    scenario = Repo.get!(Scenario, run.scenario_id)
    "bitcoin.rpc" in ScenarioSpec.required_capabilities(scenario.spec)
  end

  defp next_step(steps, status) do
    allowed =
      case status do
        "cleaning_up" -> ["cleanup"]
        "verifying" -> ["verify"]
        "running" -> ["run", "verify"]
        _ -> ["prepare", "run", "verify"]
      end

    steps |> Enum.filter(&(&1.status == "pending" and &1.phase in allowed)) |> Enum.min_by(& &1.position, fn -> nil end)
  end

  def steps(run_id), do: Repo.all(from s in Step, where: s.run_id == ^run_id, order_by: s.position)

  defp skip_remaining(run_id, phases, reason) do
    from(s in Step, where: s.run_id == ^run_id and s.status == "pending" and s.phase in ^phases)
    |> Repo.update_all(set: [status: "skipped", failure_reason: reason])
  end

  defp move(run, to) do
    path =
      case RunState.transition(run.status, to) do
        {:ok, _} -> [to]
        _ -> RunState.path(run.status, to)
      end

    Enum.reduce(path, run, fn status, acc ->
      case RunState.transition(acc.status, status) do
        {:ok, ^status} ->
          updated =
            acc
            |> Ecto.Changeset.change(status: status, started_at: acc.started_at || DateTime.utc_now())
            |> Repo.update!()

          broadcast(updated)
          updated

        {:error, reason} ->
          raise "invalid experiment transition #{inspect(reason)}"
      end
    end)
  end

  defp execute_step(run, step, owner) do
    {:ok, mod} = Action.fetch(step.action)
    env = Environments.get!(run.environment_id)
    ctx = Context.build(run, env)
    now = DateTime.utc_now()

    step =
      step
      |> Ecto.Changeset.change(
        status: "running",
        attempts: step.attempts + 1,
        started_at: now,
        checkpoint: %{"phase" => "started", "at" => DateTime.to_iso8601(now), "owner" => owner}
      )
      |> Repo.update!()

    extend_lease(run, owner, step.timeout_ms)
    Logger.metadata(experiment_id: run.id)

    task = Task.Supervisor.async_nolink(SatOps.TaskSupervisor, fn -> mod.run(step.params, ctx) end)

    outcome =
      case Task.yield(task, step.timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:ok, result}} -> {:succeeded, result}
        {:ok, {:error, reason}} -> {:failed, format(reason)}
        {:exit, reason} -> {:crashed, crash_message(reason)}
        nil -> {:timeout, "timed out after #{step.timeout_ms}ms"}
      end

    finish_step(run, step, mod, outcome)
    {:continue, Repo.get!(Run, run.id)}
  end

  defp finish_step(run, step, mod, outcome) do
    now = DateTime.utc_now()

    {status, result, reason} =
      case outcome do
        {:succeeded, result} ->
          {"succeeded", result, nil}

        {kind, reason} when kind in [:failed] ->
          if step.attempts < step.max_attempts and mod.idempotency() in [:natural, :keyed],
            do: {"pending", nil, reason},
            else: {"failed", nil, reason}

        {kind, reason} when kind in [:timeout, :crashed] ->
          cond do
            mod.idempotency() in [:natural, :keyed] and step.attempts < step.max_attempts ->
              {"pending", nil, reason}

            mod.idempotency() in [:natural, :keyed] ->
              {"failed", nil, reason}

            true ->
              {"unknown", nil,
               "#{reason}; outcome of a #{mod.idempotency()} action is unknown and it will not be repeated automatically"}
          end
      end

    step
    |> Ecto.Changeset.change(
      status: status,
      result: result,
      failure_reason: reason,
      finished_at: if(status == "pending", do: nil, else: now),
      checkpoint: Map.merge(step.checkpoint, %{"phase" => "finished", "outcome" => status})
    )
    |> Repo.update!()

    Repo.transaction(fn ->
      Events.append!(%{
        event_type: "experiment.step_completed",
        environment_id: run.environment_id,
        aggregate_type: "experiment_run",
        aggregate_id: run.id,
        correlation_id: run.correlation_id,
        payload: %{"step" => step.step_key, "action" => step.action, "status" => status, "reason" => reason}
      })
    end)
  end

  defp recover_running(run, step) do
    {:ok, mod} = Action.fetch(step.action)
    env = Environments.get!(run.environment_id)
    ctx = Context.build(run, env)

    {status, result, reason} =
      case mod.idempotency() do
        idem when idem in [:natural, :keyed] ->
          {"pending", nil, "interrupted; repeating #{idem} idempotent action"}

        :verifiable ->
          case mod.verify(step.params, ctx, step.checkpoint) do
            {:ok, result} -> {"succeeded", result, "interrupted; completion verified by state query"}
            :not_done -> {"pending", nil, "interrupted; state query shows the action did not happen"}
            :unknown -> {"unknown", nil, "interrupted; verification could not determine the outcome"}
          end

        other ->
          {"unknown", nil, "interrupted during a #{other} action; not repeated automatically, intervention required"}
      end

    step
    |> Ecto.Changeset.change(
      status: status,
      result: result,
      failure_reason: reason,
      checkpoint: Map.put(step.checkpoint, "recovered", true)
    )
    |> Repo.update!()

    {:continue, run}
  end

  defp evaluate_assertions(run, owner) do
    scenario = Repo.get!(Scenario, run.scenario_id)
    env = Environments.get!(run.environment_id)
    existing = Repo.all(from a in AssertionResult, where: a.run_id == ^run.id, select: a.position) |> MapSet.new()

    (scenario.spec["assertions"] || [])
    |> Enum.with_index()
    |> Enum.reject(fn {_, i} -> MapSet.member?(existing, i) end)
    |> Enum.each(fn {assertion, i} ->
      extend_lease(run, owner, 300_000)
      r = Assertions.evaluate(assertion, Context.build(run, env))

      Repo.insert!(%AssertionResult{
        run_id: run.id,
        position: i,
        type: r.type,
        params: assertion,
        outcome: r.outcome,
        expected: r.expected,
        actual: r.actual,
        message: r.message,
        attempts: r.attempts,
        evaluated_at: DateTime.utc_now()
      })

      broadcast(run)
    end)
  end

  defp complete(run) do
    steps = steps(run.id)
    assertions = Repo.all(from a in AssertionResult, where: a.run_id == ^run.id)
    {status, reason} = RunState.outcome(steps, assertions, run.params["abortRequested"] == true)
    cleanup = steps |> Enum.filter(&(&1.phase == "cleanup"))

    cleanup_status =
      cond do
        cleanup == [] -> "not_required"
        Enum.all?(cleanup, &(&1.status == "succeeded")) -> "completed"
        true -> "failed"
      end

    run = run |> Ecto.Changeset.change(cleanup_status: cleanup_status) |> Repo.update!()
    {:done, finalize(run, status, reason)}
  end

  defp finalize(run, status, reason) do
    if run.status in ["created", "validating", "provisioning"] do
      from(s in Step, where: s.run_id == ^run.id and s.status == "pending")
      |> Repo.update_all(set: [status: "skipped", failure_reason: "not executed: #{reason}"])
    end

    run = move(run, status)
    now = DateTime.utc_now()

    run =
      run
      |> Ecto.Changeset.change(status_reason: reason, finished_at: now, lease_owner: nil, lease_expires_at: nil)
      |> Repo.update!()

    report = Report.build(run)
    run = run |> Ecto.Changeset.change(report: report) |> Repo.update!()

    duration = DateTime.diff(now, run.started_at || run.inserted_at, :millisecond)
    failed = Repo.aggregate(from(a in AssertionResult, where: a.run_id == ^run.id and a.outcome != "passed"), :count)

    :telemetry.execute(
      [:sat_ops, :experiment, :finished],
      %{duration: System.convert_time_unit(duration, :millisecond, :native), failed_assertions: failed},
      %{
        status: status
      }
    )

    Repo.transaction(fn ->
      Events.append!(%{
        event_type: "experiment.finished",
        environment_id: run.environment_id,
        aggregate_type: "experiment_run",
        aggregate_id: run.id,
        correlation_id: run.correlation_id,
        payload: %{
          "scenario" => run.scenario_name,
          "version" => run.scenario_version,
          "status" => status,
          "reason" => reason
        }
      })
    end)

    broadcast(run)
    run
  end

  defp broadcast(run) do
    SatOps.Realtime.broadcast(run.environment_id, "experiment.progress", %{"runId" => run.id, "status" => run.status})
  end

  defp crash_message({%{__exception__: true} = e, _stack}),
    do: "action crashed: " <> (e |> Exception.message() |> String.split("\n") |> hd())

  defp crash_message(reason), do: "action crashed: " <> (reason |> inspect() |> String.slice(0, 300))

  defp format(reason) when is_binary(reason), do: reason
  defp format(reason), do: inspect(reason)
end
