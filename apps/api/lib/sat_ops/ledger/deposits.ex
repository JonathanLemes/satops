defmodule SatOps.Ledger.Deposits do
  import Ecto.Query
  alias SatOps.{Blockchain, Ledger, Repo}
  alias SatOps.Ledger.{Operation, Rules}

  @inactive [nil, "none", "cancelled", "reversed"]
  @gone ~w(conflicted replaced unknown)

  def decide(state, tx_status, confirmations, required, block_changed \\ false) do
    final = tx_status == "confirmed" and confirmations >= required
    decide_state(state, tx_status, final, block_changed)
  end

  defp decide_state(state, tx_status, final, _changed) when state in @inactive do
    cond do
      final -> [:detect, :confirm]
      tx_status in ["pending", "confirmed", "unconfirmed"] -> [:detect]
      true -> []
    end
  end

  defp decide_state("detected", tx_status, final, _changed) do
    cond do
      final -> [:confirm]
      tx_status in @gone -> [:cancel]
      true -> []
    end
  end

  defp decide_state("credited", "confirmed", final, true),
    do: if(final, do: [:reverse, :detect, :confirm], else: [:reverse, :detect])

  defp decide_state("credited", "confirmed", _final, false), do: []
  defp decide_state("credited", _tx_status, _final, _changed), do: [:reverse]
  defp decide_state(_state, _tx_status, _final, _changed), do: []

  def operation_id(txid, vout), do: "deposit:#{txid}:#{vout}"

  def evaluate(env, %{txid: txid, vout: vout, amount_sats: amount, account_ref: ref}, ctx \\ %{}) do
    tx = Blockchain.get_transaction(env.id, txid)
    status = if tx, do: tx.status, else: "unknown"
    confirmations = Blockchain.confirmations(env.id, tx)

    op =
      Ledger.upsert_operation(env.id, %{
        operation_id: operation_id(txid, vout),
        kind: "deposit",
        state: "none",
        account_ref: ref,
        amount_sats: amount,
        txid: txid,
        vout: vout
      })

    block_changed = op.state == "credited" and tx != nil and op.block_hash != nil and tx.block_hash != op.block_hash
    actions = decide(op.state, status, confirmations, env.required_confirmations, block_changed)

    Enum.reduce_while(actions, {:ok, op}, fn action, {:ok, op} ->
      case apply_action(env, op, action, %{tx: tx, confirmations: confirmations}, ctx) do
        {:ok, op} -> {:cont, {:ok, op}}
        error -> {:halt, error}
      end
    end)
  end

  defp apply_action(env, op, :detect, _facts, ctx) do
    post(env, op, "deposit_detected", base_facts(op), ctx, state: "detected")
  end

  defp apply_action(env, op, :confirm, %{tx: tx, confirmations: c}, ctx) do
    post(env, op, "deposit_confirmed", Map.merge(base_facts(op), %{block_hash: tx.block_hash, confirmations: c}), ctx,
      state: "credited",
      block_hash: tx.block_hash
    )
  end

  defp apply_action(env, op, :cancel, %{tx: tx}, ctx) do
    post(
      env,
      op,
      "deposit_cancelled",
      Map.put(base_facts(op), :reason, "transaction #{(tx && tx.status) || "missing"}"),
      ctx,
      state: "cancelled",
      generation: op.generation + 1
    )
  end

  defp apply_action(env, op, :reverse, %{tx: tx}, ctx) do
    available = Ledger.balance(env.id, SatOps.Ledger.Chart.available(op.account_ref))

    facts =
      Map.merge(base_facts(op), %{
        available_sats: available,
        reason: "transaction #{(tx && tx.status) || "missing"}",
        previous_block: op.block_hash
      })

    with {:ok, op} <-
           post(env, op, "deposit_reversed", facts, ctx,
             state: "reversed",
             generation: op.generation + 1,
             block_hash: nil
           ) do
      SatOps.Events.append!(%{
        event_type: "ledger.deposit_reversed",
        environment_id: env.id,
        aggregate_type: "operation",
        aggregate_id: op.operation_id,
        correlation_id: ctx[:correlation_id],
        causation_id: ctx[:causation_id],
        payload: %{
          "operation_id" => op.operation_id,
          "txid" => op.txid,
          "vout" => op.vout,
          "amount_sats" => op.amount_sats,
          "account_ref" => op.account_ref
        }
      })

      {:ok, op}
    end
  end

  defp base_facts(op) do
    %{
      operation_id: op.operation_id,
      generation: op.generation,
      account_ref: op.account_ref,
      amount_sats: op.amount_sats,
      txid: op.txid,
      vout: op.vout
    }
  end

  defp post(env, op, rule, facts, ctx, changes) do
    with {:ok, draft} <- Rules.build(rule, facts),
         {:ok, _journal, _} <-
           Ledger.post(env.id, draft, correlation_id: ctx[:correlation_id], causation_id: ctx[:causation_id]) do
      updated = op |> Ecto.Changeset.change(Keyword.put(changes, :updated_at, DateTime.utc_now())) |> Repo.update!()

      if rule == "deposit_confirmed" do
        SatOps.Events.append!(%{
          event_type: "ledger.deposit_credited",
          environment_id: env.id,
          aggregate_type: "operation",
          aggregate_id: op.operation_id,
          correlation_id: ctx[:correlation_id],
          causation_id: ctx[:causation_id],
          payload: %{
            "operation_id" => op.operation_id,
            "txid" => op.txid,
            "vout" => op.vout,
            "amount_sats" => op.amount_sats,
            "account_ref" => op.account_ref
          }
        })
      end

      {:ok, updated}
    end
  end

  def pending_operations(environment_id) do
    Repo.all(
      from o in Operation,
        where: o.environment_id == ^environment_id and o.kind == "deposit" and o.state in ["detected", "credited"]
    )
  end
end
