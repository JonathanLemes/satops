defmodule SatOps.LedgerDbTest do
  use SatOps.DataCase
  alias SatOps.Ledger
  alias SatOps.Ledger.{Chart, Draft}

  setup do
    {:ok, env: environment()}
  end

  test "posting updates materialized balances atomically", %{env: env} do
    fund!(env, "alice", 10_000)
    assert Ledger.balance(env.id, Chart.available("alice")) == 10_000
    assert Ledger.balance(env.id, Chart.onchain()) == 10_000
    assert Ledger.verify_invariants(env.id).ok
  end

  test "the database rejects unbalanced journals even when application validation is bypassed", %{env: env} do
    account = Ledger.ensure_account!(env.id, Chart.onchain())

    assert_raise Postgrex.Error, ~r/unbalanced|at least two/, fn ->
      Repo.transaction(fn ->
        j =
          Repo.insert!(%Ledger.Journal{
            environment_id: env.id,
            operation_id: "x",
            entry_kind: "k",
            rule_name: "r",
            rule_version: 1,
            posted_at: DateTime.utc_now()
          })

        Repo.insert_all(Ledger.Posting, [
          %{
            journal_id: j.id,
            environment_id: env.id,
            account_id: account.id,
            asset: "BTC",
            direction: "debit",
            amount_sats: 5,
            posted_at: DateTime.utc_now()
          }
        ])

        Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
      end)
    end
  end

  test "posted journals and postings are immutable", %{env: env} do
    j = fund!(env, "bob", 100)

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("UPDATE ledger_postings SET amount_sats = 1 WHERE journal_id = $1", [Ecto.UUID.dump!(j.id)])
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.query!("DELETE FROM ledger_journals WHERE id = $1", [Ecto.UUID.dump!(j.id)])
    end

    assert_raise Postgrex.Error, ~r/maintained by postings/, fn ->
      Repo.query!("UPDATE ledger_balances SET balance = 0")
    end
  end

  test "restricted accounts cannot go negative", %{env: env} do
    fund!(env, "carol", 1_000)
    assert {:error, :insufficient_funds} = Ledger.request_withdrawal(env.id, "carol", 1_001, 0, "w1", nil)
    assert {:ok, _, :posted} = Ledger.request_withdrawal(env.id, "carol", 1_000, 0, "w2", nil)
    assert Ledger.balance(env.id, Chart.available("carol")) == 0
    assert Ledger.balance(env.id, Chart.reserved("carol")) == 1_000
  end

  test "idempotency: same key and parameters replay, different parameters conflict", %{env: env} do
    fund!(env, "dave", 5_000)
    assert {:ok, j1, :posted} = Ledger.transfer(env.id, "dave", "erin", 100, "t-1", nil)
    assert {:ok, j2, :replayed} = Ledger.transfer(env.id, "dave", "erin", 100, "t-1", nil)
    assert j1.id == j2.id
    assert {:error, :idempotency_conflict} = Ledger.transfer(env.id, "dave", "erin", 999, "t-1", nil)
    assert Ledger.balance(env.id, Chart.available("erin")) == 100
  end

  test "operations of different environments never share accounts", %{env: env} do
    other = environment()
    fund!(env, "frank", 100)
    assert Ledger.balance(other.id, Chart.available("frank")) == 0
    assert {:error, :insufficient_funds} = Ledger.transfer(other.id, "frank", "gina", 50, "t", nil)
  end

  test "withdrawal settlement and release follow the reservation", %{env: env} do
    fund!(env, "hank", 10_000)
    {:ok, _, _} = Ledger.request_withdrawal(env.id, "hank", 4_000, 100, "w", nil)
    {:ok, _, _} = Ledger.settle_withdrawal(env.id, "w", :confirmed, %{txid: "abc"}, nil)
    assert {:error, {:invalid_state, "settled"}} = Ledger.settle_withdrawal(env.id, "w", :failed, %{}, nil)
    assert Ledger.balance(env.id, Chart.available("hank")) == 5_900
    assert Ledger.balance(env.id, Chart.reserved("hank")) == 0
    assert Ledger.balance(env.id, Chart.onchain()) == 5_900
  end

  test "compensating entries reverse a journal exactly once and keep history", %{env: env} do
    j = fund!(env, "ivy", 700)
    admin = user()
    assert {:ok, comp, :posted} = Ledger.compensate(env.id, j.id, "duplicate credit", admin)
    assert comp.reverses_journal_id == j.id
    assert {:ok, again, :replayed} = Ledger.compensate(env.id, j.id, "again", admin)
    assert again.id == comp.id
    assert Ledger.balance(env.id, Chart.available("ivy")) == 0
    assert length(Ledger.list_journals(env.id)) == 2
  end

  test "verification detects drift between projection and history", %{env: env} do
    fund!(env, "jay", 300)
    assert Ledger.verify_invariants(env.id).projection_drift == []
    Repo.query!("ALTER TABLE ledger_balances DISABLE TRIGGER ledger_balances_guard")

    Repo.query!(
      "UPDATE ledger_balances SET balance = balance + 1, credit_total = credit_total + 1 WHERE environment_id = $1 AND normal_balance = 'credit'",
      [Ecto.UUID.dump!(env.id)]
    )

    Repo.query!("ALTER TABLE ledger_balances ENABLE TRIGGER ledger_balances_guard")
    refute Ledger.verify_invariants(env.id).ok
  end

  test "draft validation runs before touching the database", %{env: env} do
    bad = %Draft{
      operation_id: "o",
      entry_kind: "k",
      rule_name: "r",
      rule_version: 1,
      postings: [Draft.debit("assets:onchain", 5), Draft.credit("equity:adjustments", 4)]
    }

    assert {:error, :unbalanced} = Ledger.post(env.id, bad)
  end
end
