defmodule SatOps.Blockchain do
  import Ecto.Query
  alias SatOps.{Events, Repo}

  alias SatOps.Blockchain.{
    Block,
    ChainSync,
    ForkFinder,
    Input,
    NodeObservation,
    Output,
    StatusChange,
    Transaction,
    TxState
  }

  alias SatOps.Integrations.Integration

  def tip(environment_id), do: ChainSync.local_tip(environment_id)

  def tip_height(environment_id) do
    case tip(environment_id) do
      nil -> nil
      block -> block.height
    end
  end

  def latest_observations(environment_id) do
    Repo.all(
      from i in Integration,
        as: :integration,
        where: i.environment_id == ^environment_id and i.kind == "bitcoin_core",
        left_lateral_join:
          o in subquery(
            from o in NodeObservation,
              where: o.integration_id == parent_as(:integration).id,
              order_by: [desc: o.observed_at],
              limit: 1
          ),
        on: true,
        order_by: i.name,
        select: {i, o}
    )
  end

  def reference_node(environment_id) do
    pairs = latest_observations(environment_id) |> Enum.filter(fn {i, _} -> i.enabled end)

    candidates =
      for {i, o} <- pairs, o do
        o |> Map.from_struct() |> Map.merge(%{priority: i.config["priority"] || 100, integration: i})
      end

    maybe_report_divergence(environment_id, candidates)

    case ForkFinder.select_reference(candidates) do
      nil -> fallback_node(pairs)
      selected -> {:ok, selected.integration}
    end
  end

  defp fallback_node(pairs) do
    case Enum.find(pairs, fn {_i, o} -> is_nil(o) end) do
      {i, nil} -> {:ok, i}
      _ -> {:error, :no_reachable_node}
    end
  end

  defp maybe_report_divergence(environment_id, candidates) do
    reachable = Enum.filter(candidates, & &1.reachable)

    if ForkFinder.divergent?(reachable) and Enum.all?(reachable, &recent?/1) do
      tips = reachable |> Enum.map(&{&1.integration.name, &1.best_hash, &1.height}) |> Enum.sort()

      key =
        "diverged:" <>
          (tips |> :erlang.term_to_binary() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower))

      Repo.transaction(fn ->
        Events.append!(%{
          event_type: "node.diverged",
          environment_id: environment_id,
          aggregate_type: "chain",
          aggregate_id: environment_id,
          dedupe_key: key,
          payload: %{"tips" => Enum.map(tips, fn {n, h, ht} -> %{"node" => n, "best_hash" => h, "height" => ht} end)}
        })
      end)
    end
  end

  defp recent?(o), do: DateTime.diff(DateTime.utc_now(), o.observed_at) < 120

  def record_lag(environment_id, integration) do
    with %NodeObservation{height: h} when is_integer(h) <- latest_observation(integration.id),
         local when is_integer(local) <- tip_height(environment_id) do
      :telemetry.execute([:sat_ops, :chain, :lag], %{blocks: max(h - local, 0)}, %{environment_id: environment_id})
    end
  end

  def latest_observation(integration_id) do
    Repo.one(
      from o in NodeObservation, where: o.integration_id == ^integration_id, order_by: [desc: o.observed_at], limit: 1
    )
  end

  def node_history(integration_id, limit \\ 120) do
    Repo.all(
      from o in NodeObservation,
        where: o.integration_id == ^integration_id,
        order_by: [desc: o.observed_at],
        limit: ^limit
    )
  end

  def downtime(integration_id, limit \\ 20) do
    Repo.all(
      from e in Events.Event,
        where:
          e.aggregate_type == "integration" and e.aggregate_id == ^integration_id and
            e.event_type in ["node.disconnected", "node.reconnected"],
        order_by: [desc: e.seq],
        limit: ^limit
    )
  end

  def zmq_checkpoint(integration_id) do
    Repo.one(
      from z in "zmq_checkpoints",
        where: z.integration_id == type(^integration_id, :binary_id),
        select: %{
          last_sequence: z.last_sequence,
          gaps_total: z.gaps_total,
          duplicates_total: z.duplicates_total,
          updated_at: z.updated_at
        }
    )
  end

  def chain_checkpoint(environment_id) do
    Repo.one(
      from c in "chain_checkpoints",
        where: c.environment_id == type(^environment_id, :binary_id),
        select: %{tip_hash: c.tip_hash, tip_height: c.tip_height, updated_at: c.updated_at}
    )
  end

  def blocks(environment_id, opts \\ []) do
    Block
    |> where([b], b.environment_id == ^environment_id)
    |> then(fn q -> if opts[:include_stale], do: q, else: where(q, [b], b.in_best_chain) end)
    |> then(fn q -> if opts[:before_height], do: where(q, [b], b.height < ^opts[:before_height]), else: q end)
    |> order_by([b], desc: b.height, desc: b.connected_at)
    |> limit(^min(opts[:limit] || 20, 200))
    |> Repo.all()
  end

  def stale_blocks(environment_id, limit \\ 20) do
    Repo.all(
      from b in Block,
        where: b.environment_id == ^environment_id and not b.in_best_chain,
        order_by: [desc: b.disconnected_at],
        limit: ^limit
    )
  end

  def reorganizations(environment_id, limit \\ 20),
    do: Events.list(environment_id, types: ["chain.reorganized"], limit: limit)

  def list_transactions(environment_id, filters \\ %{}, page \\ %{}) do
    limit = min(page[:first] || 25, 100)

    query =
      Transaction
      |> where([t], t.environment_id == ^environment_id)
      |> then(fn q -> if filters[:include_coinbase], do: q, else: where(q, [t], not t.is_coinbase) end)
      |> then(fn q -> if s = filters[:status], do: where(q, [t], t.status == ^s), else: q end)
      |> then(fn q -> if txid = blank(filters[:search]), do: where(q, [t], ilike(t.txid, ^"#{txid}%")), else: q end)
      |> then(fn q ->
        if addr = blank(filters[:address]) do
          where(
            q,
            [t],
            t.txid in subquery(
              from o in Output, where: o.environment_id == ^environment_id and o.address == ^addr, select: o.txid
            )
          )
        else
          q
        end
      end)
      |> then(fn q ->
        if filters[:watched_only], do: where(q, [t], t.txid in subquery(watched_txids(environment_id))), else: q
      end)
      |> then(fn q -> if c = page[:after], do: where(q, [t], t.id < ^c), else: q end)
      |> order_by([t], desc: t.id)
      |> limit(^(limit + 1))

    rows = Repo.all(query)
    {Enum.take(rows, limit), length(rows) > limit}
  end

  defp blank(nil), do: nil
  defp blank(""), do: nil
  defp blank(s), do: String.trim(s)

  def watched_txids(environment_id) do
    from o in Output,
      join: w in "watched_addresses",
      on: w.environment_id == o.environment_id and w.address == o.address,
      where: o.environment_id == ^environment_id,
      select: o.txid,
      union:
        ^from(i in Input,
          join: o in Output,
          on: o.environment_id == i.environment_id and o.txid == i.prev_txid and o.vout == i.prev_vout,
          join: w in "watched_addresses",
          on: w.environment_id == o.environment_id and w.address == o.address,
          where: i.environment_id == ^environment_id,
          select: i.txid
        )
  end

  def get_transaction(environment_id, txid), do: Repo.get_by(Transaction, environment_id: environment_id, txid: txid)

  def outputs(environment_id, txid) do
    Repo.all(from o in Output, where: o.environment_id == ^environment_id and o.txid == ^txid, order_by: o.vout)
  end

  def inputs(environment_id, txid) do
    Repo.all(
      from i in Input,
        left_join: o in Output,
        on: o.environment_id == i.environment_id and o.txid == i.prev_txid and o.vout == i.prev_vout,
        where: i.environment_id == ^environment_id and i.txid == ^txid,
        order_by: i.vin,
        select: %{
          vin: i.vin,
          prev_txid: i.prev_txid,
          prev_vout: i.prev_vout,
          value_sats: o.value_sats,
          address: o.address
        }
    )
  end

  def status_history(environment_id, txid) do
    Repo.all(from s in StatusChange, where: s.environment_id == ^environment_id and s.txid == ^txid, order_by: s.id)
  end

  def confirmations(environment_id, %Transaction{status: "confirmed", block_height: h}),
    do: TxState.confirmations(tip_height(environment_id), h)

  def confirmations(_environment_id, _tx), do: 0

  def mempool_size(environment_id) do
    Repo.aggregate(from(t in Transaction, where: t.environment_id == ^environment_id and t.status == "pending"), :count)
  end

  def transaction_volume(environment_id, hours \\ 24) do
    since = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    Repo.all(
      from t in Transaction,
        join: o in Output,
        on: o.environment_id == t.environment_id and o.txid == t.txid,
        where: t.environment_id == ^environment_id and t.first_seen_at >= ^since and not t.is_coinbase,
        group_by: fragment("date_trunc('hour', ?)", t.first_seen_at),
        order_by: fragment("date_trunc('hour', ?)", t.first_seen_at),
        select: %{
          bucket: fragment("date_trunc('hour', ?)", t.first_seen_at),
          count: count(t.id, :distinct),
          value_sats: sum(o.value_sats)
        }
    )
  end

  def tx_counts(environment_id) do
    Repo.all(
      from t in Transaction,
        where: t.environment_id == ^environment_id and not t.is_coinbase,
        group_by: t.status,
        select: {t.status, count(t.id)}
    )
    |> Map.new()
  end
end
