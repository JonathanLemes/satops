defmodule SatOps.Reconciliation.EngineTest do
  use ExUnit.Case, async: true
  alias SatOps.Reconciliation.Engine

  @now ~U[2026-11-25 12:00:00Z]
  @policy %{required_confirmations: 3, settlement_delay_seconds: 600, now: @now, chain_tx_status: %{}}

  defp fact(attrs \\ %{}) do
    Map.merge(
      %{
        "txid" => "aa",
        "vout" => 0,
        "amount_sats" => 100_000,
        "account_ref" => "c1",
        "status" => "confirmed",
        "confirmations" => 6,
        "final_at" => ~U[2026-11-25 10:00:00Z]
      },
      attrs
    )
  end

  defp rec(attrs \\ %{}) do
    Map.merge(
      %{
        "source_record_id" => "r1",
        "kind" => "deposit",
        "account_ref" => "c1",
        "amount_sats" => 100_000,
        "txid" => "aa",
        "vout" => 0,
        "status" => "credited"
      },
      attrs
    )
  end

  defp source(records, opts \\ []) do
    %{
      name: "fintech",
      kind: "demo_fintech",
      status: Keyword.get(opts, :status, :ok),
      required: true,
      records: records,
      balances: opts[:balances],
      error: opts[:error]
    }
  end

  defp kinds(result), do: result.items |> Enum.map(&{&1.state, &1.discrepancy_kind})

  test "matches a correct credit" do
    assert [{"matched", nil}] = Engine.run([fact()], [source([rec()])], @policy) |> kinds()
  end

  test "detects duplicate credit, amount mismatch and missing credit" do
    assert [{"discrepancy", "duplicate_credit"}] =
             Engine.run([fact()], [source([rec(), rec(%{"source_record_id" => "r2"})])], @policy) |> kinds()

    assert [{"discrepancy", "amount_mismatch"}] =
             Engine.run([fact()], [source([rec(%{"amount_sats" => 99_000})])], @policy) |> kinds()

    assert [{"discrepancy", "missing_credit"}] = Engine.run([fact()], [source([])], @policy) |> kinds()
  end

  test "keeps deposits pending inside the confirmation policy and the settlement delay" do
    assert [{"pending", nil}] = Engine.run([fact(%{"confirmations" => 1})], [source([])], @policy) |> kinds()

    assert [{"pending", nil}] =
             Engine.run([fact(%{"final_at" => ~U[2026-11-25 11:55:00Z]})], [source([])], @policy) |> kinds()
  end

  test "a credit for a reorganized-out transaction is an orphan credit" do
    assert [{"discrepancy", "orphan_credit"}] =
             Engine.run([fact(%{"status" => "unconfirmed", "confirmations" => 0})], [source([rec()])], @policy)
             |> kinds()
  end

  test "credits referencing unknown transactions are missing transactions" do
    assert [{"discrepancy", "missing_transaction"}] =
             Engine.run([], [source([rec(%{"txid" => "zz"})])], @policy) |> kinds()
  end

  test "wrong account is ambiguous, never matched" do
    assert [{"ambiguous", nil}] = Engine.run([fact()], [source([rec(%{"account_ref" => "c2"})])], @policy) |> kinds()
  end

  test "an unavailable required source makes the run incomplete instead of successful" do
    result = Engine.run([fact()], [source([], status: :unavailable, error: "timeout")], @policy)
    assert result.completeness == "incomplete"
    assert [{"discrepancy", "source_unavailable"}] = kinds(result)
  end

  test "balance projection is compared with a chain-derived expectation, not with itself" do
    balances = [%{"account_ref" => "c1", "available_sats" => 150_000, "reserved_sats" => 0}]
    result = Engine.run([fact()], [source([rec()], balances: balances)], @policy)
    assert {"discrepancy", "balance_mismatch"} in kinds(result)

    ok =
      Engine.run(
        [fact()],
        [source([rec()], balances: [%{"account_ref" => "c1", "available_sats" => 100_000, "reserved_sats" => 0}])],
        @policy
      )

    assert Enum.all?(ok.items, &(&1.state == "matched"))
  end

  test "pending withdrawals stay in the reported balance as reserved funds" do
    w = %{
      "source_record_id" => "w1",
      "kind" => "withdrawal",
      "account_ref" => "c1",
      "amount_sats" => 40_000,
      "status" => "pending",
      "occurred_at" => "2026-11-25T11:59:00Z"
    }

    balances = [%{"account_ref" => "c1", "available_sats" => 60_000, "reserved_sats" => 40_000}]
    result = Engine.run([fact()], [source([rec(), w], balances: balances)], @policy)
    refute {"discrepancy", "balance_mismatch"} in kinds(result)
  end

  test "completed withdrawals must exist on chain" do
    w = %{
      "source_record_id" => "w1",
      "kind" => "withdrawal",
      "account_ref" => "c1",
      "amount_sats" => 1000,
      "txid" => "ww",
      "status" => "completed"
    }

    assert [{"discrepancy", "missing_withdrawal"}] = Engine.run([], [source([w])], @policy) |> kinds()
    policy = %{@policy | chain_tx_status: %{"ww" => %{"status" => "confirmed"}}}
    assert [{"matched", nil}] = Engine.run([], [source([w])], policy) |> kinds()
  end
end
