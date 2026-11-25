defmodule SatOps.Ledger do
  import Ecto.Query
  alias SatOps.{Audit, Events, Repo}
  alias SatOps.Ledger.{Account, Balance, Chart, Draft, Journal, Operation, Posting, Rules}

  def post(environment_id, %Draft{} = draft, opts \\ []) do
    if Repo.in_transaction?() do
      do_post(environment_id, draft, opts)
    else
      started = System.monotonic_time()

      result =
        Repo.transact_with_retry(fn ->
          case do_post(environment_id, draft, opts) do
            {:ok, journal, status} -> {journal, status}
            {:error, reason} -> Repo.rollback(reason)
          end
        end)

      :telemetry.execute([:sat_ops, :ledger, :posting], %{duration: System.monotonic_time() - started}, %{
        rule: draft.rule_name
      })

      case result do
        {:ok, {journal, status}} -> {:ok, journal, status}
        {:error, reason} -> {:error, reason}
      end
    end
  rescue
    error in Postgrex.Error -> translate(error)
  end

  defp translate(%Postgrex.Error{
         postgres: %{code: :check_violation, constraint: "ledger_balances_restricted_non_negative"}
       }),
       do: {:error, :insufficient_funds}

  defp translate(%Postgrex.Error{postgres: %{code: :check_violation, message: msg}}) do
    if msg =~ "unbalanced" do
      :telemetry.execute([:sat_ops, :ledger, :invariant_violation], %{count: 1}, %{kind: "unbalanced"})
      {:error, :unbalanced}
    else
      {:error, {:check_violation, msg}}
    end
  end

  defp translate(%Postgrex.Error{postgres: %{code: :unique_violation}}), do: {:error, :duplicate_journal}
  defp translate(error), do: reraise(error, [])

  defp do_post(environment_id, draft, opts) do
    with {:ok, draft} <- Draft.validate(draft) do
      fingerprint = Draft.fingerprint(draft)
      key = "#{draft.operation_id}:#{draft.entry_kind}"

      case claim_idempotency(environment_id, key, fingerprint) do
        {:existing, %{fingerprint: ^fingerprint, journal_id: jid}} ->
          {:ok, get_journal!(jid), :replayed}

        {:existing, _} ->
          {:error, :idempotency_conflict}

        {:new, idem_id} ->
          insert_journal(environment_id, draft, idem_id, opts)
      end
    end
  end

  defp claim_idempotency(environment_id, key, fingerprint) do
    now = DateTime.utc_now()
    id = Ecto.UUID.generate()

    {count, _} =
      Repo.insert_all(
        "ledger_idempotency",
        [
          %{
            id: Ecto.UUID.dump!(id),
            environment_id: Ecto.UUID.dump!(environment_id),
            scope: "journal",
            key: key,
            fingerprint: fingerprint,
            inserted_at: now
          }
        ],
        on_conflict: :nothing,
        conflict_target: [:environment_id, :scope, :key]
      )

    if count == 1 do
      {:new, id}
    else
      existing =
        Repo.one!(
          from i in "ledger_idempotency",
            where: i.environment_id == type(^environment_id, :binary_id) and i.scope == "journal" and i.key == ^key,
            select: %{fingerprint: i.fingerprint, journal_id: type(i.journal_id, :binary_id)}
        )

      {:existing, existing}
    end
  end

  defp insert_journal(environment_id, draft, idem_id, opts) do
    now = DateTime.utc_now()
    accounts = ensure_accounts(environment_id, draft.postings)

    journal =
      Repo.insert!(%Journal{
        environment_id: environment_id,
        operation_id: draft.operation_id,
        entry_kind: draft.entry_kind,
        rule_name: draft.rule_name,
        rule_version: draft.rule_version,
        description: draft.description,
        reverses_journal_id: draft.reverses_journal_id,
        correlation_id: opts[:correlation_id],
        causation_id: opts[:causation_id],
        actor_id: opts[:actor_id],
        metadata: draft.metadata,
        posted_at: now
      })

    rows =
      draft.postings
      |> Enum.map(fn p ->
        account = Map.fetch!(accounts, {p.account_code, p.asset})

        %{
          journal_id: journal.id,
          environment_id: environment_id,
          account_id: account.id,
          asset: p.asset,
          direction: p.direction,
          amount_sats: p.amount_sats,
          posted_at: now
        }
      end)
      |> Enum.sort_by(& &1.account_id)

    Repo.insert_all(Posting, rows)
    Repo.query!("SET CONSTRAINTS ledger_postings_balanced, ledger_journals_have_postings IMMEDIATE")
    Repo.query!("SET CONSTRAINTS ledger_postings_balanced, ledger_journals_have_postings DEFERRED")

    Repo.query!("UPDATE ledger_idempotency SET journal_id = $1 WHERE id = $2", [
      Ecto.UUID.dump!(journal.id),
      Ecto.UUID.dump!(idem_id)
    ])

    Events.append!(%{
      event_type: "ledger.journal_posted",
      environment_id: environment_id,
      aggregate_type: "operation",
      aggregate_id: draft.operation_id,
      correlation_id: opts[:correlation_id],
      causation_id: opts[:causation_id],
      payload: %{
        "journal_id" => journal.id,
        "operation_id" => draft.operation_id,
        "entry_kind" => draft.entry_kind,
        "rule" => "#{draft.rule_name}@v#{draft.rule_version}",
        "postings" => Enum.map(draft.postings, &Map.new(&1, fn {k, v} -> {to_string(k), v} end))
      }
    })

    {:ok, journal, :posted}
  end

  def ensure_accounts(environment_id, postings) do
    postings
    |> Enum.map(&{&1.account_code, &1.asset})
    |> Enum.uniq()
    |> Map.new(fn {code, asset} -> {{code, asset}, ensure_account!(environment_id, code, asset)} end)
  end

  def ensure_account!(environment_id, code, asset \\ "BTC") do
    case Repo.get_by(Account, environment_id: environment_id, code: code, asset: asset) do
      %Account{} = account ->
        account

      nil ->
        {:ok, spec} = Chart.account_spec(code)
        now = DateTime.utc_now()

        Repo.insert!(
          struct(
            Account,
            Map.merge(spec, %{
              environment_id: environment_id,
              code: code,
              asset: asset,
              name: code,
              inserted_at: now,
              updated_at: now
            })
          ),
          on_conflict: :nothing,
          conflict_target: [:environment_id, :code, :asset]
        )

        Repo.get_by!(Account, environment_id: environment_id, code: code, asset: asset)
    end
  end

  def get_journal!(id), do: Repo.get!(Journal, id) |> Repo.preload(postings: :account)
  def get_journal(id), do: Repo.get(Journal, id) |> then(&(&1 && Repo.preload(&1, postings: :account)))

  def list_journals(environment_id, opts \\ []) do
    Journal
    |> where([j], j.environment_id == ^environment_id)
    |> then(fn q -> if op = opts[:operation_id], do: where(q, [j], j.operation_id == ^op), else: q end)
    |> then(fn q -> if c = opts[:correlation_id], do: where(q, [j], j.correlation_id == ^c), else: q end)
    |> then(fn q -> if b = opts[:before], do: where(q, [j], j.posted_at < ^b), else: q end)
    |> order_by([j], desc: j.posted_at, desc: j.id)
    |> limit(^min(opts[:limit] || 50, 200))
    |> preload(postings: :account)
    |> Repo.all()
  end

  def accounts(environment_id) do
    Repo.all(
      from a in Account,
        left_join: b in Balance,
        on: b.account_id == a.id,
        where: a.environment_id == ^environment_id,
        order_by: a.code,
        select: %{
          account: a,
          balance: coalesce(b.balance, 0),
          debit_total: coalesce(b.debit_total, 0),
          credit_total: coalesce(b.credit_total, 0)
        }
    )
  end

  def balance(environment_id, code, asset \\ "BTC") do
    Repo.one(
      from a in Account,
        join: b in Balance,
        on: b.account_id == a.id,
        where: a.environment_id == ^environment_id and a.code == ^code and a.asset == ^asset,
        select: b.balance
    ) || 0
  end

  def customer_balances(environment_id) do
    Repo.all(
      from a in Account,
        join: b in Balance,
        on: b.account_id == a.id,
        where: a.environment_id == ^environment_id and like(a.code, "liabilities:customers:%"),
        select: {a.owner_ref, a.code, b.balance}
    )
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {ref, rows} ->
      pick = fn suffix ->
        Enum.find_value(rows, 0, fn {_, code, bal} -> if String.ends_with?(code, suffix), do: bal end)
      end

      %{
        account_ref: ref,
        available_sats: pick.(":available"),
        pending_sats: pick.(":pending"),
        reserved_sats: pick.(":reserved")
      }
    end)
    |> Enum.sort_by(& &1.account_ref)
  end

  def verify_invariants(environment_id) do
    env = Ecto.UUID.dump!(environment_id)

    %{rows: unbalanced} =
      Repo.query!(
        """
        SELECT journal_id::text FROM ledger_postings WHERE environment_id = $1
        GROUP BY journal_id, asset
        HAVING sum(CASE WHEN direction='debit' THEN amount_sats ELSE 0 END) <> sum(CASE WHEN direction='credit' THEN amount_sats ELSE 0 END)
        """,
        [env]
      )

    %{rows: drift} =
      Repo.query!(
        """
        SELECT a.code, b.balance, COALESCE(p.computed, 0)
        FROM ledger_accounts a
        JOIN ledger_balances b ON b.account_id = a.id
        LEFT JOIN (
          SELECT p.account_id,
                 sum(CASE WHEN p.direction = a2.normal_balance THEN p.amount_sats ELSE -p.amount_sats END) AS computed
          FROM ledger_postings p JOIN ledger_accounts a2 ON a2.id = p.account_id
          WHERE p.environment_id = $1 GROUP BY p.account_id
        ) p ON p.account_id = a.id
        WHERE a.environment_id = $1 AND b.balance <> COALESCE(p.computed, 0)
        """,
        [env]
      )

    %{rows: [[debits, credits]]} =
      Repo.query!(
        "SELECT COALESCE(sum(CASE WHEN direction='debit' THEN amount_sats END),0)::bigint, COALESCE(sum(CASE WHEN direction='credit' THEN amount_sats END),0)::bigint FROM ledger_postings WHERE environment_id = $1",
        [env]
      )

    %{rows: negative} =
      Repo.query!(
        "SELECT a.code, b.balance FROM ledger_balances b JOIN ledger_accounts a ON a.id = b.account_id WHERE b.environment_id = $1 AND b.restricted AND b.balance < 0",
        [env]
      )

    ok = unbalanced == [] and drift == [] and debits == credits and negative == []
    unless ok, do: :telemetry.execute([:sat_ops, :ledger, :invariant_violation], %{count: 1}, %{kind: "verification"})

    %{
      balanced: unbalanced == [] and debits == credits,
      total_debits: debits,
      total_credits: credits,
      unbalanced_journals: List.flatten(unbalanced),
      projection_drift:
        Enum.map(drift, fn [code, stored, computed] -> %{code: code, stored: stored, computed: computed} end),
      negative_restricted: Enum.map(negative, fn [code, bal] -> %{code: code, balance: bal} end),
      ok: ok
    }
  end

  def duplicate_credits(environment_id) do
    %{rows: [[n]]} =
      Repo.query!(
        """
        SELECT count(*) FROM (
          SELECT o.txid, o.vout FROM ledger_operations o
          JOIN ledger_journals j ON j.environment_id = o.environment_id AND j.operation_id = o.operation_id
          WHERE o.environment_id = $1 AND o.kind = 'deposit'
          GROUP BY o.txid, o.vout
          HAVING sum(CASE WHEN j.entry_kind LIKE 'confirmed:%' THEN 1 WHEN j.entry_kind LIKE 'reversed:%' THEN -1 ELSE 0 END) > 1
        ) d
        """,
        [Ecto.UUID.dump!(environment_id)]
      )

    n
  end

  def operations(environment_id, opts \\ []) do
    Operation
    |> where([o], o.environment_id == ^environment_id)
    |> then(fn q -> if k = opts[:kind], do: where(q, [o], o.kind == ^k), else: q end)
    |> then(fn q -> if s = opts[:state], do: where(q, [o], o.state == ^s), else: q end)
    |> then(fn q -> if t = opts[:txid], do: where(q, [o], o.txid == ^t), else: q end)
    |> order_by([o], desc: o.updated_at)
    |> limit(^min(opts[:limit] || 100, 1000))
    |> Repo.all()
  end

  def get_operation(environment_id, operation_id),
    do: Repo.get_by(Operation, environment_id: environment_id, operation_id: operation_id)

  def transfer(environment_id, from_ref, to_ref, amount, idempotency_key, actor) do
    run_rule(
      environment_id,
      "internal_transfer",
      %{operation_id: "transfer:#{idempotency_key}", from_ref: from_ref, to_ref: to_ref, amount_sats: amount},
      actor
    )
  end

  def request_withdrawal(environment_id, ref, amount, fee, idempotency_key, actor) do
    op_id = "withdrawal:#{idempotency_key}"

    Repo.transact_with_retry(fn ->
      upsert_operation(environment_id, %{
        operation_id: op_id,
        kind: "withdrawal",
        state: "reserved",
        account_ref: ref,
        amount_sats: amount,
        fee_sats: fee
      })

      case Rules.build("withdrawal_requested", %{
             operation_id: op_id,
             account_ref: ref,
             amount_sats: amount,
             fee_sats: fee
           }) do
        {:ok, draft} ->
          case do_post(environment_id, draft, actor_id: actor && actor.id) do
            {:ok, journal, status} -> {journal, status}
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> unwrap()
  rescue
    error in Postgrex.Error -> translate(error)
  end

  def settle_withdrawal(environment_id, idempotency_key, outcome, attrs, actor) when outcome in [:confirmed, :failed] do
    op_id = "withdrawal:#{idempotency_key}"

    Repo.transact_with_retry(fn ->
      op =
        Repo.one(
          from o in Operation,
            where: o.environment_id == ^environment_id and o.operation_id == ^op_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(op) ->
          Repo.rollback(:not_found)

        op.state != "reserved" ->
          Repo.rollback({:invalid_state, op.state})

        true ->
          {rule, state} =
            if outcome == :confirmed, do: {"withdrawal_confirmed", "settled"}, else: {"withdrawal_failed", "released"}

          facts = %{
            operation_id: op_id,
            account_ref: op.account_ref,
            amount_sats: op.amount_sats,
            fee_sats: op.fee_sats,
            txid: attrs[:txid],
            reason: attrs[:reason]
          }

          {:ok, draft} = Rules.build(rule, facts)

          case do_post(environment_id, draft, actor_id: actor && actor.id) do
            {:ok, journal, status} ->
              op |> Ecto.Changeset.change(state: state, txid: attrs[:txid] || op.txid) |> Repo.update!()
              {journal, status}

            {:error, reason} ->
              Repo.rollback(reason)
          end
      end
    end)
    |> unwrap()
  rescue
    error in Postgrex.Error -> translate(error)
  end

  def compensate(environment_id, journal_id, reason, actor) do
    original = get_journal(journal_id)

    cond do
      is_nil(original) or original.environment_id != environment_id ->
        {:error, :not_found}

      true ->
        postings =
          Enum.map(
            original.postings,
            &%{account_code: &1.account.code, asset: &1.asset, amount_sats: &1.amount_sats, direction: &1.direction}
          )

        facts = %{operation_id: original.operation_id, journal_id: original.id, postings: postings, reason: reason}

        with {:ok, journal, status} <- run_rule(environment_id, "compensating_entry", facts, actor) do
          Audit.record!(actor, "ledger.compensating_entry_posted",
            environment_id: environment_id,
            resource_type: "journal",
            resource_id: journal.id,
            changes: %{reverses: journal_id, reason: reason}
          )

          {:ok, journal, status}
        end
    end
  end

  defp run_rule(environment_id, rule, facts, actor) do
    with {:ok, draft} <- Rules.build(rule, facts) do
      post(environment_id, draft, actor_id: actor && actor.id)
    end
  end

  defp unwrap({:ok, {journal, status}}), do: {:ok, journal, status}
  defp unwrap({:error, reason}), do: {:error, reason}

  def upsert_operation(environment_id, attrs) do
    now = DateTime.utc_now()

    Repo.insert!(
      struct(Operation, Map.merge(attrs, %{environment_id: environment_id, inserted_at: now, updated_at: now})),
      on_conflict: :nothing,
      conflict_target: [:environment_id, :operation_id]
    )

    Repo.one!(
      from o in Operation,
        where: o.environment_id == ^environment_id and o.operation_id == ^attrs.operation_id,
        lock: "FOR UPDATE"
    )
  end

  def timeline(environment_id, operation_id) do
    journals = list_journals(environment_id, operation_id: operation_id, limit: 200) |> Enum.reverse()
    op = get_operation(environment_id, operation_id)
    correlation_ids = journals |> Enum.map(& &1.correlation_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    aggregate_ids = [operation_id] ++ if(op && op.txid, do: [op.txid], else: [])

    events =
      Repo.all(
        from e in Events.Event,
          where:
            e.environment_id == ^environment_id and
              (e.aggregate_id in ^aggregate_ids or e.correlation_id in ^correlation_ids),
          order_by: e.seq,
          limit: 500
      )

    %{operation: op, journals: journals, events: events}
  end
end
