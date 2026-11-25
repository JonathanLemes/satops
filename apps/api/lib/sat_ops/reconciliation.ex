defmodule SatOps.Reconciliation do
  import Ecto.Query
  require Logger
  alias SatOps.{Audit, Blockchain, Environments, Events, Integrations, Ledger, Repo}
  alias SatOps.Blockchain.{Output, Transaction}
  alias SatOps.Reconciliation.{Discrepancy, Engine, Item, Note, Run}

  @default_policy %{
    "name" => "default",
    "version" => 1,
    "settlementDelaySeconds" => 600,
    "sources" => nil,
    "requiredSources" => nil
  }

  def default_policy, do: @default_policy

  def policy_for(env) do
    case SatOps.Configuration.applied_spec("ReconciliationPolicy", env.slug) do
      %{"spec" => spec, "revision" => rev} ->
        Map.merge(@default_policy, spec) |> Map.merge(%{"name" => env.slug, "version" => rev})

      _ ->
        @default_policy
    end
  end

  def enqueue(environment_id, trigger, actor \\ nil) do
    env = Environments.get!(environment_id)
    policy = policy_for(env)

    Repo.transaction(fn ->
      run =
        Repo.insert!(%Run{
          environment_id: env.id,
          policy_name: policy["name"],
          policy_version: policy["version"],
          policy: policy,
          status: "queued",
          trigger: trigger,
          correlation_id: Ecto.UUID.generate(),
          requested_by: actor && actor.id
        })

      %{run_id: run.id} |> SatOps.Reconciliation.Workers.Run.new() |> Oban.insert!()
      if actor, do: Audit.record!(actor, "reconciliation.requested", resource: run)
      run
    end)
  end

  def execute(run_id) do
    run = Repo.get!(Run, run_id)
    env = Environments.get!(run.environment_id)
    now = DateTime.utc_now()
    run = run |> Ecto.Changeset.change(status: "running", started_at: now) |> Repo.update!()
    SatOps.Realtime.broadcast(env.id, "reconciliation.progress", %{"runId" => run.id, "status" => "running"})

    try do
      tip = Blockchain.tip(env.id)
      sources = collect_sources(env, run.policy)
      chain_facts = chain_facts(env)

      withdrawal_txids =
        sources
        |> Enum.flat_map(&(&1[:records] || []))
        |> Enum.filter(&(&1["kind"] == "withdrawal" and &1["txid"]))
        |> Enum.map(& &1["txid"])

      policy = %{
        required_confirmations: env.required_confirmations,
        settlement_delay_seconds: run.policy["settlementDelaySeconds"] || 600,
        now: now,
        chain_tx_status: chain_tx_status(env.id, withdrawal_txids)
      }

      result = Engine.run(chain_facts, sources, policy)
      ledger_check = Ledger.verify_invariants(env.id)

      items =
        if ledger_check.ok do
          result.items
        else
          result.items ++
            [
              %{
                match_key: "native-ledger|invariants",
                state: "discrepancy",
                discrepancy_kind: "unbalanced_journal",
                source: "native-ledger",
                reason: "native ledger invariant check failed",
                records: [Map.new(ledger_check, fn {k, v} -> {to_string(k), v} end)],
                amount_sats: nil,
                txid: nil,
                vout: nil
              }
            ]
        end

      persist(run, env, tip, sources, items, result.completeness)
    rescue
      error ->
        Logger.error("reconciliation #{run.id} failed: #{Exception.message(error)}")

        run
        |> Ecto.Changeset.change(
          status: "failed",
          error: Exception.message(error) |> String.slice(0, 1000),
          finished_at: DateTime.utc_now()
        )
        |> Repo.update!()

        :telemetry.execute([:sat_ops, :reconciliation, :run], %{count: 1, open_discrepancies: open_count(env.id)}, %{
          status: "failed"
        })

        {:error, :failed}
    end
  end

  defp persist(run, env, tip, sources, items, completeness) do
    now = DateTime.utc_now()
    status = if completeness == "complete", do: "completed", else: "incomplete"

    Repo.transact_with_retry(fn ->
      rows =
        Enum.map(items, fn i ->
          %{
            run_id: run.id,
            environment_id: env.id,
            match_key: i.match_key,
            state: i.state,
            discrepancy_kind: i.discrepancy_kind,
            reason: i.reason,
            records: Enum.map(i.records, &json_safe/1),
            amount_sats: i.amount_sats,
            txid: i.txid,
            vout: i.vout
          }
        end)

      rows |> Enum.chunk_every(500) |> Enum.each(&Repo.insert_all(Item, &1))

      seen =
        for i <- items, i.state in ["discrepancy", "ambiguous"] do
          upsert_discrepancy(env, run, i, now)
        end

      if completeness == "complete" do
        from(d in Discrepancy,
          where:
            d.environment_id == ^env.id and d.state in ["open", "investigating"] and d.fingerprint not in ^seen and
              d.kind != "source_unavailable"
        )
        |> Repo.update_all(
          set: [state: "resolved", resolution: "no longer observed in run #{run.id}", resolved_at: now, updated_at: now]
        )
      end

      if completeness == "complete" do
        from(d in Discrepancy,
          where:
            d.environment_id == ^env.id and d.state == "open" and d.kind == "source_unavailable" and
              d.fingerprint not in ^seen
        )
        |> Repo.update_all(
          set: [
            state: "resolved",
            resolution: "source available again in run #{run.id}",
            resolved_at: now,
            updated_at: now
          ]
        )
      end

      summary = Engine.summarize(items)

      updated =
        run
        |> Ecto.Changeset.change(
          status: status,
          completeness: completeness,
          reference_height: tip && tip.height,
          reference_hash: tip && tip.hash,
          sources: Enum.map(sources, &source_meta/1),
          summary: summary,
          finished_at: now
        )
        |> Repo.update!()

      Events.append!(%{
        event_type: if(status == "completed", do: "reconciliation.completed", else: "reconciliation.incomplete"),
        environment_id: env.id,
        aggregate_type: "reconciliation_run",
        aggregate_id: run.id,
        correlation_id: run.correlation_id,
        payload: %{"run_id" => run.id, "summary" => summary, "reason" => unavailable_reason(sources)}
      })

      updated
    end)
    |> tap(fn {:ok, r} ->
      :telemetry.execute([:sat_ops, :reconciliation, :run], %{count: 1, open_discrepancies: open_count(env.id)}, %{
        status: r.status
      })

      SatOps.Realtime.broadcast(env.id, "reconciliation.progress", %{"runId" => r.id, "status" => r.status})
    end)
  end

  defp unavailable_reason(sources) do
    sources
    |> Enum.filter(&(&1.status != :ok))
    |> Enum.map_join("; ", &"#{&1.name}: #{&1.error}")
    |> then(&if(&1 == "", do: nil, else: &1))
  end

  defp json_safe(term), do: term |> Jason.encode!() |> Jason.decode!()

  defp source_meta(s) do
    %{
      "name" => s.name,
      "kind" => s.kind,
      "status" => to_string(s.status),
      "required" => s.required,
      "records" => length(s[:records] || []),
      "balances" => length(s[:balances] || []),
      "watermark" => s[:watermark],
      "error" => s[:error]
    }
  end

  defp upsert_discrepancy(env, run, item, now) do
    fingerprint = "#{item.discrepancy_kind || item.state}:#{item.match_key}"

    existing =
      Repo.one(
        from d in Discrepancy,
          where: d.environment_id == ^env.id and d.fingerprint == ^fingerprint and d.state in ["open", "investigating"],
          lock: "FOR UPDATE"
      )

    case existing do
      nil ->
        ignored =
          Repo.exists?(
            from d in Discrepancy,
              where: d.environment_id == ^env.id and d.fingerprint == ^fingerprint and d.state == "ignored"
          )

        unless ignored do
          d =
            Repo.insert!(%Discrepancy{
              environment_id: env.id,
              fingerprint: fingerprint,
              kind: item.discrepancy_kind || "ambiguous_match",
              severity: severity(item.discrepancy_kind),
              match_key: item.match_key,
              txid: item.txid,
              vout: item.vout,
              amount_sats: item.amount_sats,
              reason: item.reason,
              evidence: %{"records" => Enum.map(item.records, &json_safe/1), "source" => item.source},
              first_run_id: run.id,
              last_run_id: run.id
            })

          Events.append!(%{
            event_type: "reconciliation.discrepancy_detected",
            environment_id: env.id,
            aggregate_type: "discrepancy",
            aggregate_id: d.id,
            correlation_id: run.correlation_id,
            payload: %{
              "discrepancy_id" => d.id,
              "kind" => d.kind,
              "fingerprint" => fingerprint,
              "txid" => d.txid,
              "source" => item.source,
              "reason" => d.reason
            }
          })
        end

      d ->
        d
        |> Ecto.Changeset.change(
          last_run_id: run.id,
          occurrences: d.occurrences + 1,
          reason: item.reason,
          updated_at: now
        )
        |> Repo.update!()
    end

    fingerprint
  end

  defp severity(kind)
       when kind in [
              "duplicate_credit",
              "orphan_credit",
              "unbalanced_journal",
              "balance_mismatch",
              "missing_transaction"
            ],
       do: "critical"

  defp severity(kind) when kind in ["settlement_delay", "source_unavailable"], do: "warning"
  defp severity(_), do: "high"

  def collect_sources(env, policy) do
    integrations = Integrations.list(env.id, enabled: true) |> Enum.filter(&Integrations.financial_source?/1)
    names = policy["sources"] || ["native-ledger" | Enum.map(integrations, & &1.name)]
    required = policy["requiredSources"] || names

    native =
      if "native-ledger" in names do
        [native_source(env, "native-ledger" in required)]
      else
        []
      end

    external =
      for i <- integrations, i.name in names do
        fetch_external(i, i.name in required)
      end

    missing =
      for n <- names, n != "native-ledger", not Enum.any?(integrations, &(&1.name == n)) do
        %{
          name: n,
          kind: "missing",
          status: :unavailable,
          required: n in required,
          error: "integration not found or disabled",
          records: [],
          balances: nil
        }
      end

    native ++ external ++ missing
  end

  defp native_source(env, required) do
    records =
      Ledger.operations(env.id, limit: 1000)
      |> Enum.map(fn op ->
        %{
          "source_record_id" => op.operation_id,
          "kind" => op.kind,
          "account_ref" => op.account_ref,
          "asset" => op.asset,
          "amount_sats" => op.amount_sats,
          "fee_sats" => op.fee_sats,
          "txid" => op.txid,
          "vout" => op.vout,
          "status" => native_status(op),
          "occurred_at" => DateTime.to_iso8601(op.inserted_at)
        }
      end)

    balances =
      Ledger.customer_balances(env.id)
      |> Enum.map(&Map.new(&1, fn {k, v} -> {to_string(k), v} end))

    %{
      name: "native-ledger",
      kind: "native_ledger",
      status: :ok,
      required: required,
      records: records,
      balances: balances,
      watermark: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp native_status(%{kind: "deposit", state: "credited"}), do: "credited"
  defp native_status(%{kind: "deposit", state: "detected"}), do: "pending"
  defp native_status(%{kind: "deposit", state: s}), do: s
  defp native_status(%{kind: "withdrawal", state: "settled"}), do: "completed"
  defp native_status(%{kind: "withdrawal", state: "reserved"}), do: "pending"
  defp native_status(%{state: s}), do: s

  defp fetch_external(integration, required) do
    adapter = Integrations.adapter(integration.kind)

    with {:ok, creds} <- Integrations.credentials(integration),
         {:ok, %{records: records, watermark: wm}} <- adapter.fetch_records(integration, creds, []) do
      balances =
        case adapter.fetch_balances(integration, creds, []) do
          {:ok, %{balances: b}} -> b
          _ -> nil
        end

      Integrations.touch_sync(integration.id, %{"watermark" => wm})

      %{
        name: integration.name,
        kind: integration.kind,
        status: :ok,
        required: required,
        records: records,
        balances: balances,
        watermark: wm
      }
    else
      {:error, reason} ->
        Integrations.record_health(integration, {:error, reason})

        %{
          name: integration.name,
          kind: integration.kind,
          status: :unavailable,
          required: required,
          error: Integrations.format_error(reason),
          records: [],
          balances: nil
        }
    end
  end

  def chain_facts(env) do
    tip = Blockchain.tip_height(env.id)
    req = env.required_confirmations

    rows =
      Repo.all(
        from o in Output,
          join: a in "watched_addresses",
          on: a.environment_id == o.environment_id and a.address == o.address,
          join: w in "watched_wallets",
          on: w.id == a.wallet_id,
          join: t in Transaction,
          on: t.environment_id == o.environment_id and t.txid == o.txid,
          where: o.environment_id == ^env.id and not is_nil(w.account_ref),
          distinct: [o.txid, o.vout],
          select: %{
            txid: o.txid,
            vout: o.vout,
            address: o.address,
            amount: o.value_sats,
            account_ref: w.account_ref,
            status: t.status,
            block_height: t.block_height
          }
      )

    final_times = final_times(env.id, rows, req)

    Enum.map(rows, fn r ->
      confs = SatOps.Blockchain.TxState.confirmations(tip, r.block_height)

      %{
        "txid" => r.txid,
        "vout" => r.vout,
        "address" => r.address,
        "amount_sats" => r.amount,
        "account_ref" => r.account_ref,
        "status" => r.status,
        "confirmations" => if(r.status == "confirmed", do: confs, else: 0),
        "block_height" => r.block_height,
        "final_at" => r.block_height && Map.get(final_times, r.block_height + req - 1)
      }
    end)
  end

  defp final_times(environment_id, rows, req) do
    heights = rows |> Enum.map(& &1.block_height) |> Enum.reject(&is_nil/1) |> Enum.map(&(&1 + req - 1)) |> Enum.uniq()

    Repo.all(
      from b in SatOps.Blockchain.Block,
        where: b.environment_id == ^environment_id and b.in_best_chain and b.height in ^heights,
        select: {b.height, b.connected_at}
    )
    |> Map.new()
  end

  defp chain_tx_status(_environment_id, []), do: %{}

  defp chain_tx_status(environment_id, txids) do
    Repo.all(
      from t in Transaction,
        where: t.environment_id == ^environment_id and t.txid in ^txids,
        select: {t.txid, %{"status" => t.status, "txid" => t.txid}}
    )
    |> Map.new()
  end

  def list_runs(environment_id, limit \\ 30) do
    Repo.all(from r in Run, where: r.environment_id == ^environment_id, order_by: [desc: r.inserted_at], limit: ^limit)
  end

  def get_run(id), do: Repo.get(Run, id)

  def items(run_id, opts \\ []) do
    Item
    |> where([i], i.run_id == ^run_id)
    |> then(fn q -> if s = opts[:state], do: where(q, [i], i.state == ^s), else: q end)
    |> order_by([i], i.id)
    |> limit(^min(opts[:limit] || 500, 5000))
    |> Repo.all()
  end

  def list_discrepancies(environment_id, opts \\ []) do
    Discrepancy
    |> where([d], d.environment_id == ^environment_id)
    |> then(fn q -> if s = opts[:states], do: where(q, [d], d.state in ^s), else: q end)
    |> then(fn q -> if k = opts[:kind], do: where(q, [d], d.kind == ^k), else: q end)
    |> order_by([d], desc: d.updated_at)
    |> limit(^min(opts[:limit] || 100, 500))
    |> Repo.all()
  end

  def open_count(environment_id) do
    Repo.aggregate(
      from(d in Discrepancy, where: d.environment_id == ^environment_id and d.state in ["open", "investigating"]),
      :count
    )
  end

  def get_discrepancy(id),
    do: Repo.get(Discrepancy, id) |> Repo.preload(notes: from(n in Note, order_by: n.inserted_at))

  def add_note(%Discrepancy{} = d, body, kind, data, actor) when kind in ["note", "link", "suggestion"] do
    Repo.transaction(fn ->
      note =
        Repo.insert!(%Note{
          discrepancy_id: d.id,
          author_id: actor.id,
          author_email: actor.email,
          kind: kind,
          body: body,
          data: data || %{},
          inserted_at: DateTime.utc_now()
        })

      Audit.record!(actor, "discrepancy.#{kind}_added",
        environment_id: d.environment_id,
        resource_type: "discrepancy",
        resource_id: d.id
      )

      note
    end)
  end

  def transition(%Discrepancy{} = d, to, note, actor) when to in ["investigating", "resolved", "ignored", "open"] do
    cond do
      to == "ignored" and (is_nil(note) or String.trim(note) == "") ->
        {:error, :justification_required}

      d.state in ["resolved", "ignored"] and to != "open" ->
        {:error, {:invalid_transition, d.state, to}}

      true ->
        Repo.transaction(fn ->
          changes =
            [state: to, updated_at: DateTime.utc_now()] ++
              if(to in ["resolved", "ignored"],
                do: [resolution: note, resolved_by: actor.id, resolved_at: DateTime.utc_now()],
                else: []
              )

          updated =
            d |> Ecto.Changeset.change(changes) |> Ecto.Changeset.optimistic_lock(:lock_version) |> Repo.update!()

          if note && note != "",
            do:
              Repo.insert!(%Note{
                discrepancy_id: d.id,
                author_id: actor.id,
                author_email: actor.email,
                kind: "note",
                body: note,
                inserted_at: DateTime.utc_now()
              })

          Audit.record!(actor, "discrepancy.#{to}",
            environment_id: d.environment_id,
            resource_type: "discrepancy",
            resource_id: d.id,
            changes: %{from: d.state, to: to}
          )

          updated
        end)
    end
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  def suggestion(%Discrepancy{} = d) do
    source = d.evidence["source"]

    case {d.kind, source} do
      {"duplicate_credit", "native-ledger"} ->
        "Post a compensating entry for the duplicated confirmed journal of #{d.txid}:#{d.vout} (Ledger > Journals > Compensate)."

      {"duplicate_credit", ext} ->
        "#{ext} credited the same outpoint more than once. Correct it in #{ext}; SatOps never edits external ledgers."

      {"missing_credit", ext} ->
        "Confirm the deposit address mapping and credit #{d.amount_sats} sats in #{ext} if the deposit is legitimate."

      {"orphan_credit", ext} ->
        "The credited transaction is no longer valid on the reference chain (possible reorganization). Reverse the credit in #{ext} if it does not reconfirm."

      {"amount_mismatch", ext} ->
        "Align the credited amount in #{ext} with the on-chain output value."

      {"balance_mismatch", ext} ->
        "Rebuild the balance projection of #{ext} from its records and compare against the chain-derived expectation."

      {"source_unavailable", ext} ->
        "Check the health of #{ext} and request a new reconciliation once it is reachable."

      {"settlement_delay", ext} ->
        "Check whether the withdrawal was broadcast by #{ext} and whether it is waiting for confirmations."

      _ ->
        "Inspect the evidence and link records manually if a match exists."
    end
  end

  def export_run(run_id) do
    run = get_run(run_id)
    items = items(run_id, limit: 5000)

    %{
      run:
        Map.take(run, [
          :id,
          :environment_id,
          :policy_name,
          :policy_version,
          :policy,
          :status,
          :completeness,
          :reference_height,
          :reference_hash,
          :sources,
          :summary,
          :started_at,
          :finished_at,
          :trigger
        ]),
      items:
        Enum.map(
          items,
          &Map.take(&1, [:match_key, :state, :discrepancy_kind, :reason, :amount_sats, :txid, :vout, :records])
        )
    }
  end
end
