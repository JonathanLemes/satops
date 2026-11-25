defmodule SatOps.Experiments.Report do
  import Ecto.Query
  alias SatOps.{Environments, Repo}
  alias SatOps.Experiments.{AssertionResult, Run, Scenario, Step}

  def build(%Run{} = run) do
    scenario = Repo.get(Scenario, run.scenario_id)
    env = Environments.get(run.environment_id)
    steps = Repo.all(from s in Step, where: s.run_id == ^run.id, order_by: s.position)
    assertions = Repo.all(from a in AssertionResult, where: a.run_id == ^run.id, order_by: a.position)
    from_t = run.started_at || run.inserted_at
    to_t = run.finished_at || DateTime.utc_now()

    events =
      Repo.all(
        from e in SatOps.Events.Event,
          where:
            e.environment_id == ^run.environment_id and e.observed_at >= ^from_t and e.observed_at <= ^to_t and
              e.event_type in [
                "block.connected",
                "block.disconnected",
                "chain.reorganized",
                "transaction.confirmed",
                "transaction.unconfirmed",
                "transaction.conflicted",
                "transaction.replaced",
                "node.disconnected",
                "node.reconnected"
              ],
          order_by: e.seq,
          limit: 500,
          select: %{seq: e.seq, type: e.event_type, aggregate: e.aggregate_id, at: e.observed_at}
      )

    journals =
      Repo.all(
        from j in SatOps.Ledger.Journal,
          where: j.environment_id == ^run.environment_id and j.posted_at >= ^from_t and j.posted_at <= ^to_t,
          order_by: j.posted_at,
          limit: 500,
          select: %{
            id: j.id,
            operation: j.operation_id,
            kind: j.entry_kind,
            rule: fragment("? || '@v' || ?", j.rule_name, j.rule_version),
            at: j.posted_at
          }
      )

    discrepancies =
      Repo.all(
        from d in SatOps.Reconciliation.Discrepancy,
          where: d.environment_id == ^run.environment_id and d.inserted_at >= ^from_t and d.inserted_at <= ^to_t,
          select: %{
            id: d.id,
            kind: d.kind,
            state: d.state,
            reason: d.reason,
            source: fragment("?->>'source'", d.evidence)
          }
      )

    %{
      "schemaVersion" => 1,
      "scenario" => %{
        "name" => run.scenario_name,
        "version" => run.scenario_version,
        "title" => scenario && scenario.title,
        "guarantee" => scenario && scenario.guarantee
      },
      "environment" =>
        env &&
          %{
            "slug" => env.slug,
            "network" => env.network,
            "requiredConfirmations" => env.required_confirmations,
            "settings" => SatOps.Redactor.redact(env.settings)
          },
      "seed" => run.seed,
      "result" => %{"status" => run.status, "reason" => run.status_reason, "cleanup" => run.cleanup_status},
      "timing" => %{
        "startedAt" => from_t,
        "finishedAt" => run.finished_at,
        "durationMs" => DateTime.diff(to_t, from_t, :millisecond)
      },
      "steps" =>
        Enum.map(steps, fn s ->
          %{
            "id" => s.step_key,
            "phase" => s.phase,
            "action" => s.action,
            "status" => s.status,
            "attempts" => s.attempts,
            "durationMs" => s.started_at && s.finished_at && DateTime.diff(s.finished_at, s.started_at, :millisecond),
            "result" => SatOps.Redactor.redact(s.result),
            "failure" => s.failure_reason && SatOps.Redactor.redact(s.failure_reason)
          }
        end),
      "assertions" =>
        Enum.map(assertions, fn a ->
          %{
            "type" => a.type,
            "outcome" => a.outcome,
            "expected" => a.expected,
            "actual" => a.actual,
            "message" => a.message,
            "attempts" => a.attempts
          }
        end),
      "blockchainEvents" => events,
      "financialEffects" => journals,
      "discrepancies" => discrepancies,
      "metrics" => %{
        "steps" => length(steps),
        "stepsFailed" => Enum.count(steps, &(&1.status == "failed")),
        "assertionsFailed" => Enum.count(assertions, &(&1.outcome != "passed")),
        "journalsPosted" => length(journals),
        "blockchainEvents" => length(events)
      },
      "reproducibility" =>
        "Inputs (scenario version, seed and parameters) are recorded. Block hashes, timestamps and txids depend on node state and are not reproducible bit for bit."
    }
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
