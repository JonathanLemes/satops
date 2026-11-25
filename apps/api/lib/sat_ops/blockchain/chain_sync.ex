defmodule SatOps.Blockchain.ChainSync do
  import Ecto.Query
  require Logger
  alias SatOps.{Events, Repo}
  alias SatOps.Blockchain.{Block, ForkFinder, Input, Output, StatusChange, Transaction, TxState}
  alias SatOps.Infrastructure.Bitcoin.RPC

  @max_blocks_per_run 50
  @max_mempool_per_run 500

  def run(env, %RPC{} = rpc, opts \\ []) do
    max_blocks = Keyword.get(opts, :max_blocks, @max_blocks_per_run)
    correlation_id = Keyword.get(opts, :correlation_id, Ecto.UUID.generate())

    with {:ok, info} <- RPC.call(rpc, "getblockchaininfo"),
         :ok <- SatOps.Environments.assert_regtest_chain(info["chain"]),
         {:ok, result} <- sync_blocks(env, rpc, info, max_blocks, correlation_id),
         {:ok, mempool} <- maybe_sync_mempool(env, rpc, result, correlation_id) do
      {:ok, Map.put(result, :mempool, mempool)}
    end
  end

  def local_tip(environment_id) do
    Repo.one(
      from b in Block,
        where: b.environment_id == ^environment_id and b.in_best_chain,
        order_by: [desc: b.height],
        limit: 1
    )
  end

  defp sync_blocks(env, rpc, info, max_blocks, correlation_id) do
    tip = local_tip(env.id)
    remote_height = info["blocks"]
    remote_best = info["bestblockhash"]

    cond do
      tip && tip.hash == remote_best ->
        {:ok, %{connected: [], disconnected: [], caught_up: true, tip_height: tip.height, tip_hash: tip.hash}}

      true ->
        with {:ok, ancestor, disconnected} <- find_ancestor(env, rpc, tip),
             start_height = if(ancestor, do: elem(ancestor, 0) + 1, else: 0),
             end_height = min(remote_height, start_height + max_blocks - 1),
             {:ok, blocks} <- fetch_blocks(rpc, start_height, end_height, ancestor) do
          apply_changes(env, tip, disconnected, blocks, ancestor, correlation_id)
          |> case do
            {:ok, applied} ->
              caught_up = end_height >= remote_height
              last = List.last(blocks)

              {:ok,
               %{
                 connected: Enum.map(blocks, & &1["hash"]),
                 disconnected: Enum.map(disconnected, &elem(&1, 1)),
                 caught_up: caught_up,
                 tip_height: if(last, do: last["height"], else: tip && tip.height),
                 tip_hash: if(last, do: last["hash"], else: tip && tip.hash),
                 reorganized: applied.reorganized
               }}

            error ->
              error
          end
        end
    end
  end

  defp find_ancestor(_env, _rpc, nil), do: {:ok, nil, []}

  defp find_ancestor(env, rpc, _tip) do
    local_desc =
      Repo.all(
        from b in Block,
          where: b.environment_id == ^env.id and b.in_best_chain,
          order_by: [desc: b.height],
          limit: 1_000,
          select: {b.height, b.hash}
      )

    ForkFinder.find(local_desc, fn hash ->
      case RPC.call(rpc, "getblockheader", [hash, true]) do
        {:ok, %{"confirmations" => c}} -> {:ok, c >= 1}
        {:error, {:rpc, -5, _}} -> {:ok, false}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp fetch_blocks(_rpc, start_height, end_height, _ancestor) when start_height > end_height, do: {:ok, []}

  defp fetch_blocks(rpc, start_height, end_height, ancestor) do
    Enum.reduce_while(start_height..end_height, {:ok, [], ancestor && elem(ancestor, 1)}, fn height, {:ok, acc, prev} ->
      with {:ok, hash} <- RPC.call(rpc, "getblockhash", [height]),
           {:ok, block} <- RPC.call(rpc, "getblock", [hash, 3]),
           :ok <- check_link(block, prev) do
        {:cont, {:ok, [block | acc], hash}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, blocks, _} -> {:ok, Enum.reverse(blocks)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_link(_block, nil), do: :ok
  defp check_link(%{"previousblockhash" => prev}, prev), do: :ok
  defp check_link(_, _), do: {:error, :chain_changed_during_fetch}

  defp apply_changes(env, tip, disconnected, blocks, ancestor, correlation_id) do
    Repo.transact_with_retry(fn ->
      Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", ["chain:" <> env.id])
      current = local_tip(env.id)

      if (current && current.hash) != (tip && tip.hash) do
        Repo.rollback(:local_tip_changed)
      end

      now = DateTime.utc_now()
      Enum.each(disconnected, fn {height, hash} -> disconnect_block(env, height, hash, now, correlation_id) end)
      Enum.each(blocks, fn block -> connect_block(env, block, now, correlation_id) end)

      reorganized = disconnected != []

      if reorganized do
        Events.append!(%{
          event_type: "chain.reorganized",
          environment_id: env.id,
          network_id: "regtest",
          aggregate_type: "chain",
          aggregate_id: env.id,
          correlation_id: correlation_id,
          payload: %{
            "old_tip" => tip && tip.hash,
            "old_height" => tip && tip.height,
            "ancestor_hash" => ancestor && elem(ancestor, 1),
            "ancestor_height" => ancestor && elem(ancestor, 0),
            "disconnected" => Enum.map(disconnected, &elem(&1, 1)),
            "connected" => Enum.map(blocks, & &1["hash"]),
            "depth" => length(disconnected)
          }
        })

        :telemetry.execute([:sat_ops, :chain, :reorganization], %{count: 1, depth: length(disconnected)}, %{
          environment_id: env.id
        })
      end

      case List.last(blocks) do
        nil -> :ok
        last -> update_checkpoint(env.id, last["hash"], last["height"], now)
      end

      %{reorganized: reorganized}
    end)
  end

  defp update_checkpoint(environment_id, hash, height, now) do
    Repo.query!(
      """
      INSERT INTO chain_checkpoints (environment_id, tip_hash, tip_height, updated_at) VALUES ($1, $2, $3, $4)
      ON CONFLICT (environment_id) DO UPDATE SET tip_hash = $2, tip_height = $3, updated_at = $4
      """,
      [Ecto.UUID.dump!(environment_id), hash, height, now]
    )
  end

  defp disconnect_block(env, height, hash, now, correlation_id) do
    from(b in Block, where: b.environment_id == ^env.id and b.hash == ^hash)
    |> Repo.update_all(set: [in_best_chain: false, disconnected_at: now])

    {:ok, event} =
      Events.append!(%{
        event_type: "block.disconnected",
        environment_id: env.id,
        network_id: "regtest",
        aggregate_type: "block",
        aggregate_id: hash,
        correlation_id: correlation_id,
        payload: %{"hash" => hash, "height" => height}
      })

    txs = Repo.all(from t in Transaction, where: t.environment_id == ^env.id and t.block_hash == ^hash)

    Enum.each(txs, fn tx ->
      change_status(env, tx, "unconfirmed", now,
        block_hash: nil,
        block_height: nil,
        reason: "block #{hash} disconnected",
        causation_id: event.id,
        correlation_id: correlation_id,
        previous_block: hash
      )
    end)
  end

  defp connect_block(env, block, now, correlation_id) do
    hash = block["hash"]
    height = block["height"]

    Repo.insert!(
      %Block{
        environment_id: env.id,
        hash: hash,
        height: height,
        prev_hash: block["previousblockhash"],
        chainwork: chainwork(block["chainwork"]),
        block_time: DateTime.from_unix!(block["time"]),
        tx_count: length(block["tx"]),
        in_best_chain: true,
        connected_at: now
      },
      on_conflict: [set: [in_best_chain: true, connected_at: now, disconnected_at: nil]],
      conflict_target: [:environment_id, :hash]
    )

    {:ok, event} =
      Events.append!(%{
        event_type: "block.connected",
        environment_id: env.id,
        network_id: "regtest",
        aggregate_type: "block",
        aggregate_id: hash,
        aggregate_version: height,
        correlation_id: correlation_id,
        payload: %{
          "hash" => hash,
          "height" => height,
          "prev_hash" => block["previousblockhash"],
          "tx_count" => length(block["tx"])
        }
      })

    Enum.each(block["tx"], fn tx -> connect_tx(env, tx, hash, height, now, event.id, correlation_id) end)
  end

  defp connect_tx(env, raw, block_hash, height, now, causation_id, correlation_id) do
    coinbase? = match?([%{"coinbase" => _} | _], raw["vin"])
    fee = if coinbase?, do: nil, else: compute_fee(raw)
    tx = ensure_tx(env, raw, "confirmed", now, coinbase?, fee)
    store_io(env, raw)

    if tx.status == "confirmed" and tx.block_hash == block_hash do
      :ok
    else
      updated =
        change_status(env, tx, "confirmed", now,
          block_hash: block_hash,
          block_height: height,
          reason: "included in block #{height}",
          causation_id: causation_id,
          correlation_id: correlation_id,
          emit: not coinbase?,
          fee: fee
        )

      unless coinbase?, do: mark_conflicts(env, updated, now, causation_id, correlation_id)
    end
  end

  defp ensure_tx(env, raw, initial_status, now, coinbase?, fee) do
    txid = raw["txid"]

    case Repo.get_by(Transaction, environment_id: env.id, txid: txid) do
      nil ->
        Repo.insert!(%Transaction{
          environment_id: env.id,
          txid: txid,
          status: if(initial_status == "confirmed", do: "observed", else: initial_status),
          is_coinbase: coinbase?,
          vsize: raw["vsize"],
          fee_sats: fee,
          first_seen_at: now,
          status_changed_at: now,
          version: 1
        })

      tx ->
        tx
    end
  end

  defp store_io(env, raw) do
    txid = raw["txid"]

    outputs =
      Enum.map(raw["vout"], fn o ->
        spk = o["scriptPubKey"] || %{}

        %{
          environment_id: Ecto.UUID.dump!(env.id),
          txid: txid,
          vout: o["n"],
          value_sats: RPC.btc_to_sats(o["value"]),
          address: spk["address"],
          script_type: spk["type"]
        }
      end)

    Repo.insert_all("tx_outputs", outputs, on_conflict: :nothing, conflict_target: [:environment_id, :txid, :vout])

    inputs =
      raw["vin"]
      |> Enum.with_index()
      |> Enum.reject(fn {i, _} -> Map.has_key?(i, "coinbase") end)
      |> Enum.map(fn {i, idx} ->
        %{environment_id: Ecto.UUID.dump!(env.id), txid: txid, vin: idx, prev_txid: i["txid"], prev_vout: i["vout"]}
      end)

    Repo.insert_all("tx_inputs", inputs, on_conflict: :nothing, conflict_target: [:environment_id, :txid, :vin])

    Enum.each(inputs, fn i ->
      from(o in Output,
        where: o.environment_id == ^env.id and o.txid == ^i.prev_txid and o.vout == ^i.prev_vout
      )
      |> Repo.update_all(set: [spent_by_txid: txid, spent_by_vin: i.vin])
    end)
  end

  defp compute_fee(raw) do
    inputs = Enum.map(raw["vin"], &get_in(&1, ["prevout", "value"]))

    if Enum.all?(inputs, & &1) do
      in_sats = inputs |> Enum.map(&RPC.btc_to_sats/1) |> Enum.sum()
      out_sats = raw["vout"] |> Enum.map(&RPC.btc_to_sats(&1["value"])) |> Enum.sum()
      in_sats - out_sats
    end
  end

  defp mark_conflicts(env, tx, now, causation_id, correlation_id) do
    rivals =
      Repo.all(
        from i in Input,
          join: mine in Input,
          on:
            mine.environment_id == i.environment_id and mine.prev_txid == i.prev_txid and mine.prev_vout == i.prev_vout,
          join: t in Transaction,
          on: t.environment_id == i.environment_id and t.txid == i.txid,
          where:
            mine.environment_id == ^env.id and mine.txid == ^tx.txid and i.txid != ^tx.txid and
              t.status in ["observed", "pending", "unconfirmed", "unknown"],
          distinct: true,
          select: t
      )

    Enum.each(rivals, fn rival ->
      change_status(env, rival, "conflicted", now,
        reason: "inputs spent by #{tx.txid}",
        causation_id: causation_id,
        correlation_id: correlation_id,
        conflicts_with: [tx.txid]
      )
    end)
  end

  def change_status(env, %Transaction{} = tx, to, now, opts) do
    case TxState.transition(tx.status, to) do
      {:ok, ^to} ->
        changes =
          [
            status: to,
            status_changed_at: now,
            version: tx.version + 1
          ] ++
            Keyword.take(opts, [:block_hash, :block_height]) ++
            if(opts[:fee], do: [fee_sats: opts[:fee]], else: []) ++
            if(opts[:conflicts_with],
              do: [conflicts_with: Enum.uniq(tx.conflicts_with ++ opts[:conflicts_with])],
              else: []
            ) ++
            if(opts[:replaced_by], do: [replaced_by_txid: opts[:replaced_by]], else: [])

        {1, [updated]} =
          from(t in Transaction, where: t.id == ^tx.id and t.version == ^tx.version, select: t)
          |> Repo.update_all(set: changes)

        event_id = maybe_emit(env, updated, tx.status, opts)

        Repo.insert!(%StatusChange{
          environment_id: env.id,
          txid: tx.txid,
          from_status: tx.status,
          to_status: to,
          block_hash: opts[:block_hash] || opts[:previous_block],
          block_height: opts[:block_height],
          reason: opts[:reason],
          event_id: event_id,
          inserted_at: now
        })

        updated

      :noop ->
        tx

      {:error, reason} ->
        Logger.warning("ignored transaction transition #{inspect(reason)} for #{tx.txid}")
        tx
    end
  end

  defp maybe_emit(env, tx, from, opts) do
    with true <- Keyword.get(opts, :emit, not tx.is_coinbase),
         type when is_binary(type) <- TxState.event_for(tx.status) do
      outputs =
        Repo.all(
          from o in Output,
            where: o.environment_id == ^env.id and o.txid == ^tx.txid,
            order_by: o.vout,
            select: %{"vout" => o.vout, "address" => o.address, "value_sats" => o.value_sats}
        )

      {_, event} =
        Events.append!(%{
          event_type: type,
          environment_id: env.id,
          network_id: "regtest",
          aggregate_type: "transaction",
          aggregate_id: tx.txid,
          aggregate_version: tx.version,
          correlation_id: opts[:correlation_id],
          causation_id: opts[:causation_id],
          dedupe_key: "tx:#{tx.txid}:v#{tx.version}",
          payload: %{
            "txid" => tx.txid,
            "from_status" => from,
            "status" => tx.status,
            "block_hash" => tx.block_hash || opts[:previous_block],
            "block_height" => tx.block_height,
            "fee_sats" => tx.fee_sats,
            "outputs" => outputs,
            "reason" => opts[:reason]
          }
        })

      event.id
    else
      _ -> nil
    end
  end

  defp chainwork(hex) when is_binary(hex), do: hex |> String.to_integer(16) |> Decimal.new()

  defp maybe_sync_mempool(env, rpc, %{caught_up: true}, correlation_id), do: sync_mempool(env, rpc, correlation_id)
  defp maybe_sync_mempool(_env, _rpc, _result, _correlation_id), do: {:ok, %{skipped: true}}

  def sync_mempool(env, rpc, correlation_id) do
    with {:ok, mempool} <- RPC.call(rpc, "getrawmempool", [false]) do
      in_mempool = MapSet.new(mempool)

      known =
        Repo.all(
          from t in Transaction,
            where: t.environment_id == ^env.id and t.txid in ^mempool,
            select: {t.txid, t.status}
        )
        |> Map.new()

      new_txids = mempool |> Enum.reject(&Map.has_key?(known, &1)) |> Enum.take(@max_mempool_per_run)
      fetched = new_txids |> Enum.map(&fetch_mempool_tx(rpc, &1)) |> Enum.reject(&is_nil/1)

      revived = for {txid, status} <- known, status in ["unconfirmed", "unknown", "observed"], do: txid

      stale =
        Repo.all(
          from t in Transaction,
            where: t.environment_id == ^env.id and t.status in ["pending", "observed"],
            select: t.txid
        )
        |> Enum.reject(&MapSet.member?(in_mempool, &1))

      Repo.transact_with_retry(fn ->
        now = DateTime.utc_now()

        Enum.each(fetched, fn {raw, fee} ->
          tx = ensure_tx(env, raw, "observed", now, false, fee)
          store_io(env, raw)
          change_status(env, tx, "pending", now, reason: "seen in mempool", correlation_id: correlation_id, fee: fee)
        end)

        Enum.each(revived, fn txid ->
          tx = Repo.get_by!(Transaction, environment_id: env.id, txid: txid)
          change_status(env, tx, "pending", now, reason: "back in mempool", correlation_id: correlation_id)
        end)

        Enum.each(stale, fn txid ->
          tx = Repo.get_by!(Transaction, environment_id: env.id, txid: txid)
          resolve_missing(env, tx, now, correlation_id)
        end)

        %{added: length(fetched), revived: length(revived), dropped: length(stale)}
      end)
    end
  end

  defp fetch_mempool_tx(rpc, txid) do
    with {:ok, raw} <- RPC.call(rpc, "getrawtransaction", [txid, true]) do
      fee =
        case RPC.call(rpc, "getmempoolentry", [txid]) do
          {:ok, %{"fees" => %{"base" => base}}} -> RPC.btc_to_sats(base)
          _ -> nil
        end

      {raw, fee}
    else
      _ -> nil
    end
  end

  defp resolve_missing(env, tx, now, correlation_id) do
    replacement =
      Repo.one(
        from i in Input,
          join: mine in Input,
          on:
            mine.environment_id == i.environment_id and mine.prev_txid == i.prev_txid and mine.prev_vout == i.prev_vout,
          join: t in Transaction,
          on: t.environment_id == i.environment_id and t.txid == i.txid,
          where:
            mine.environment_id == ^env.id and mine.txid == ^tx.txid and i.txid != ^tx.txid and
              t.status in ["pending", "confirmed"],
          limit: 1,
          select: t.txid
      )

    if replacement do
      change_status(env, tx, "replaced", now,
        reason: "inputs spent by #{replacement}",
        replaced_by: replacement,
        correlation_id: correlation_id
      )
    else
      change_status(env, tx, "unknown", now, reason: "no longer in mempool", correlation_id: correlation_id)
    end
  end
end
