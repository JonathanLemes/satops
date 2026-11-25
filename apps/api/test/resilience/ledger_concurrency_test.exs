defmodule SatOps.Resilience.LedgerConcurrencyTest do
  use SatOps.CommittedCase, async: false
  alias SatOps.Ledger
  alias SatOps.Ledger.Chart

  @tag :resilience
  test "concurrent withdrawals on independent connections never overdraw an account" do
    env = environment()
    fund!(env, "conc", 10_000)

    results =
      1..20
      |> Task.async_stream(fn i -> Ledger.request_withdrawal(env.id, "conc", 1_000, 0, "cw-#{i}", nil) end,
        max_concurrency: 20,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    accepted = Enum.count(results, &match?({:ok, _, :posted}, &1))
    rejected = Enum.count(results, &match?({:error, :insufficient_funds}, &1))
    assert accepted == 10
    assert rejected == 10
    assert Ledger.balance(env.id, Chart.available("conc")) == 0
    assert Ledger.verify_invariants(env.id).ok
  end

  @tag :resilience
  test "the same event applied 100 times concurrently has a single financial effect" do
    env = environment()
    fund!(env, "src", 1_000_000)

    1..100
    |> Task.async_stream(fn _ -> Ledger.transfer(env.id, "src", "dst", 777, "same-op", nil) end,
      max_concurrency: 25,
      timeout: 30_000
    )
    |> Enum.each(fn {:ok, r} -> assert match?({:ok, _, _}, r) end)

    assert Ledger.balance(env.id, Chart.available("dst")) == 777
    assert length(Ledger.list_journals(env.id, operation_id: "transfer:same-op")) == 1
  end

  @tag :resilience
  test "opposite transfers between the same accounts do not deadlock" do
    env = environment()
    fund!(env, "x", 100_000)
    fund!(env, "y", 100_000)

    results =
      1..40
      |> Task.async_stream(
        fn i ->
          if rem(i, 2) == 0,
            do: Ledger.transfer(env.id, "x", "y", 10, "xy-#{i}", nil),
            else: Ledger.transfer(env.id, "y", "x", 10, "yx-#{i}", nil)
        end,
        max_concurrency: 40,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.all?(results, &match?({:ok, _, :posted}, &1))
    assert Ledger.balance(env.id, Chart.available("x")) + Ledger.balance(env.id, Chart.available("y")) == 200_000
  end

  @tag :resilience
  test "a worker crash before commit leaves no partial effect and the retry after commit does not duplicate" do
    env = environment()
    fund!(env, "p", 1_000)

    {:ok, draft} =
      SatOps.Ledger.Rules.build("internal_transfer", %{
        operation_id: "crash",
        from_ref: "p",
        to_ref: "q",
        amount_sats: 400
      })

    {pid, ref} =
      spawn_monitor(fn ->
        SatOps.Repo.transaction(fn ->
          {:ok, _, _} = Ledger.post(env.id, draft)
          exit(:boom)
        end)
      end)

    assert_receive {:DOWN, ^ref, :process, ^pid, :boom}, 5_000
    assert Ledger.list_journals(env.id, operation_id: "crash") == []
    assert {:ok, _, :posted} = Ledger.post(env.id, draft)
    assert {:ok, _, :replayed} = Ledger.post(env.id, draft)
    assert Ledger.balance(env.id, Chart.available("q")) == 400
  end
end
