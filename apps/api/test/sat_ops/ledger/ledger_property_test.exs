defmodule SatOps.LedgerPropertyTest do
  use SatOps.DataCase
  use ExUnitProperties
  alias SatOps.Ledger
  alias SatOps.Ledger.Chart

  @refs ["a", "b", "c"]

  defp op_gen do
    one_of([
      tuple({constant(:fund), member_of(@refs), integer(1..50_000)}),
      tuple({constant(:transfer), member_of(@refs), member_of(@refs), integer(1..60_000)}),
      tuple({constant(:withdraw), member_of(@refs), integer(1..60_000)}),
      tuple({constant(:settle), integer(0..20), boolean()}),
      tuple({constant(:duplicate), integer(0..20)})
    ])
  end

  property "random sequences preserve double-entry invariants, non-negative restricted balances and idempotency" do
    check all(ops <- list_of(op_gen(), min_length: 1, max_length: 25), max_runs: 40) do
      env = environment()

      {_, model} =
        Enum.reduce(Enum.with_index(ops), {[], %{}}, fn {op, i}, {history, model} ->
          key = "k#{i}"
          result = apply_op(env, op, key, history)
          {[{op, key, result} | history], update_model(model, op, result)}
        end)

      check = Ledger.verify_invariants(env.id)
      assert check.ok, inspect(check)

      for ref <- @refs do
        assert Ledger.balance(env.id, Chart.available(ref)) >= 0
        assert Ledger.balance(env.id, Chart.available(ref)) == Map.get(model, ref, 0)
      end
    end
  end

  defp apply_op(env, {:fund, ref, amt}, key, _), do: {:ok, fund!(env, ref, amt, key)}
  defp apply_op(env, {:transfer, a, b, amt}, key, _), do: Ledger.transfer(env.id, a, b, amt, key, nil)
  defp apply_op(env, {:withdraw, ref, amt}, key, _), do: Ledger.request_withdrawal(env.id, ref, amt, 0, key, nil)

  defp apply_op(env, {:settle, n, ok?}, _key, history) do
    case Enum.filter(history, &match?({{:withdraw, _, _}, _, {:ok, _, :posted}}, &1)) |> Enum.at(n) do
      nil ->
        :skip

      {{:withdraw, _, amt}, wkey, _} ->
        {:settled, ok?, amt, Ledger.settle_withdrawal(env.id, wkey, if(ok?, do: :confirmed, else: :failed), %{}, nil)}
    end
  end

  defp apply_op(env, {:duplicate, n}, _key, history) do
    case Enum.at(history, n) do
      {{:transfer, a, b, amt} = op, k, _} -> {:dup, op, Ledger.transfer(env.id, a, b, amt, k, nil)}
      {{:withdraw, ref, amt} = op, k, _} -> {:dup, op, Ledger.request_withdrawal(env.id, ref, amt, 0, k, nil)}
      _ -> :skip
    end
  end

  defp update_model(m, {:fund, ref, amt}, _), do: Map.update(m, ref, amt, &(&1 + amt))

  defp update_model(m, {:transfer, a, b, amt}, {:ok, _, :posted}) when a != b,
    do: m |> Map.update(a, -amt, &(&1 - amt)) |> Map.update(b, amt, &(&1 + amt))

  defp update_model(m, {:withdraw, ref, amt}, {:ok, _, :posted}), do: Map.update(m, ref, -amt, &(&1 - amt))
  defp update_model(m, {:settle, _, _}, {:settled, false, amt, {:ok, j, :posted}}), do: release(m, j, amt)

  defp update_model(m, {:duplicate, _}, {:dup, original, result}), do: update_model(m, original, result)
  defp update_model(m, _op, _), do: m

  defp release(m, journal, amt) do
    journal = SatOps.Ledger.get_journal!(journal.id)
    posting = Enum.find(journal.postings, &(&1.direction == "credit"))
    owner = posting.account.owner_ref
    Map.update(m, owner, amt, &(&1 + amt))
  end
end
