defmodule SatOps.ReconciliationDbTest do
  use SatOps.DataCase
  alias SatOps.{Reconciliation, Repo}

  setup do
    {:ok, env: environment()}
  end

  test "a run with only the native ledger completes and persists items", %{env: env} do
    fund!(env, "alice", 1_000)
    {:ok, run} = Reconciliation.enqueue(env.id, "test")
    assert {:ok, done} = Reconciliation.execute(run.id)
    assert done.status == "completed"
    assert done.completeness == "complete"
    assert is_list(done.sources) and hd(done.sources)["name"] == "native-ledger"
  end

  test "internal transfers in the native ledger do not produce false balance mismatches", %{env: env} do
    fund!(env, "alice", 5_000)
    post_transfer!(env, "alice", "bob", 1_200, "t1")
    {:ok, run} = Reconciliation.enqueue(env.id, "test")
    assert {:ok, %{status: "completed"}} = Reconciliation.execute(run.id)
    kinds = Reconciliation.list_discrepancies(env.id, states: ["open"]) |> Enum.map(& &1.kind)
    refute "balance_mismatch" in kinds
  end

  test "a missing required source yields an incomplete run and a source_unavailable discrepancy", %{env: env} do
    {:ok, _} =
      SatOps.Configuration.apply_document(
        %{
          "apiVersion" => "satops.io/v1alpha1",
          "kind" => "ReconciliationPolicy",
          "metadata" => %{"name" => env.slug},
          "spec" => %{
            "environmentRef" => env.slug,
            "sources" => ["native-ledger", "ghost"],
            "requiredSources" => ["native-ledger", "ghost"]
          }
        },
        actor: nil
      )

    {:ok, run} = Reconciliation.enqueue(env.id, "test")
    assert {:ok, done} = Reconciliation.execute(run.id)
    assert done.status == "incomplete"
    assert [%{kind: "source_unavailable"}] = Reconciliation.list_discrepancies(env.id, states: ["open"])
    assert Repo.aggregate(SatOps.Reconciliation.Item, :count) > 0
  end
end
