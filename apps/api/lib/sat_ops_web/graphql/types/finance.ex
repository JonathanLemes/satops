defmodule SatOpsWeb.GraphQL.Types.Finance do
  use Absinthe.Schema.Notation
  import SatOpsWeb.GraphQL.Helpers
  alias SatOps.{Ledger, Reconciliation}
  alias SatOps.Ledger.Rules
  alias SatOpsWeb.GraphQL.Authorize

  object :ledger_account do
    field :id, non_null(:id)
    field :code, non_null(:string)
    field :name, non_null(:string)
    field :type, non_null(:string)
    field :normal_balance, non_null(:string)
    field :asset, non_null(:string)
    field :restricted, non_null(:boolean)
    field :owner_ref, :string
    field :balance_sats, non_null(:sats)
    field :debit_total, non_null(:sats)
    field :credit_total, non_null(:sats)
  end

  object :posting do
    field :id, non_null(:id)
    field :account_code, non_null(:string), resolve: fn p, _, _ -> {:ok, p.account.code} end
    field :asset, non_null(:string)
    field :direction, non_null(:string)
    field :amount_sats, non_null(:sats)
  end

  object :journal do
    field :id, non_null(:id)
    field :operation_id, non_null(:string)
    field :entry_kind, non_null(:string)
    field :rule_name, non_null(:string)
    field :rule_version, non_null(:integer)
    field :description, :string
    field :reverses_journal_id, :id
    field :correlation_id, :id
    field :causation_id, :id
    field :metadata, :json
    field :posted_at, non_null(:datetime)
    field :postings, non_null(list_of(non_null(:posting)))
  end

  object :ledger_operation do
    field :id, non_null(:id)
    field :operation_id, non_null(:string)
    field :kind, non_null(:string)
    field :state, non_null(:string)
    field :account_ref, :string
    field :asset, non_null(:string)
    field :amount_sats, non_null(:sats)
    field :fee_sats, non_null(:sats)
    field :txid, :string
    field :vout, :integer
    field :block_hash, :string
    field :generation, non_null(:integer)
    field :updated_at, :datetime
  end

  object :customer_balance do
    field :account_ref, non_null(:string)
    field :available_sats, non_null(:sats)
    field :pending_sats, non_null(:sats)
    field :reserved_sats, non_null(:sats)
  end

  object :ledger_invariants do
    field :ok, non_null(:boolean)
    field :balanced, non_null(:boolean)
    field :total_debits, non_null(:sats)
    field :total_credits, non_null(:sats)
    field :unbalanced_journals, non_null(list_of(non_null(:string)))
    field :projection_drift, :json
    field :negative_restricted, :json
    field :duplicate_credits, non_null(:integer)
  end

  object :financial_rule do
    field :name, non_null(:string)
    field :version, non_null(:integer)
    field :current, non_null(:boolean)
  end

  object :operation_timeline do
    field :operation, :ledger_operation
    field :journals, non_null(list_of(non_null(:journal)))
    field :events, non_null(list_of(non_null(:domain_event)))
  end

  object :posting_result do
    field :journal, non_null(:journal)
    field :status, non_null(:string)
  end

  object :reconciliation_run do
    field :id, non_null(:id)
    field :environment_id, non_null(:id)
    field :policy_name, non_null(:string)
    field :policy_version, non_null(:integer)
    field :policy, :json
    field :status, non_null(:string)
    field :completeness, non_null(:string)
    field :trigger, non_null(:string)
    field :reference_height, :integer
    field :reference_hash, :string
    field :sources, :json
    field :summary, :json
    field :error, :string
    field :started_at, :datetime
    field :finished_at, :datetime
    field :inserted_at, non_null(:datetime)

    field :items, non_null(list_of(non_null(:reconciliation_item))) do
      arg :state, :string
      arg :limit, :integer, default_value: 500
      resolve fn run, args, _ -> {:ok, Reconciliation.items(run.id, state: args[:state], limit: args.limit)} end
    end
  end

  object :reconciliation_item do
    field :id, non_null(:id)
    field :match_key, non_null(:string)
    field :state, non_null(:string)
    field :discrepancy_kind, :string
    field :reason, non_null(:string)
    field :records, :json
    field :amount_sats, :sats
    field :txid, :string
    field :vout, :integer
  end

  object :discrepancy_note do
    field :id, non_null(:id)
    field :author_email, :string
    field :kind, non_null(:string)
    field :body, non_null(:string)
    field :data, :json
    field :inserted_at, non_null(:datetime)
  end

  object :discrepancy do
    field :id, non_null(:id)
    field :environment_id, non_null(:id)
    field :kind, non_null(:string)
    field :state, non_null(:string)
    field :severity, non_null(:string)
    field :match_key, non_null(:string)
    field :txid, :string
    field :vout, :integer
    field :amount_sats, :sats
    field :reason, non_null(:string)
    field :evidence, :json
    field :source, :string, resolve: fn d, _, _ -> {:ok, d.evidence["source"]} end
    field :first_run_id, non_null(:id)
    field :last_run_id, non_null(:id)
    field :occurrences, non_null(:integer)
    field :resolution, :string
    field :resolved_at, :datetime
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
    field :lock_version, non_null(:integer)
    field :suggestion, non_null(:string), resolve: fn d, _, _ -> {:ok, Reconciliation.suggestion(d)} end

    field :notes, non_null(list_of(non_null(:discrepancy_note))) do
      resolve fn d, _, _ ->
        d = SatOps.Repo.preload(d, :notes)
        {:ok, Enum.sort_by(d.notes, & &1.inserted_at, DateTime)}
      end
    end
  end

  object :finance_queries do
    field :ledger_accounts, non_null(list_of(non_null(:ledger_account))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"ledger.read", :environment_id}

      resolve fn args, _ ->
        {:ok,
         Ledger.accounts(args.environment_id)
         |> Enum.map(fn %{account: a} = r ->
           a
           |> Map.from_struct()
           |> Map.merge(%{balance_sats: r.balance, debit_total: r.debit_total, credit_total: r.credit_total})
         end)}
      end
    end

    field :journals, non_null(list_of(non_null(:journal))) do
      arg :environment_id, non_null(:id)
      arg :operation_id, :string
      arg :correlation_id, :id
      arg :before, :datetime
      arg :limit, :integer, default_value: 50
      middleware Authorize, {:"ledger.read", :environment_id}
      resolve fn args, _ -> {:ok, Ledger.list_journals(args.environment_id, Map.to_list(args))} end
    end

    field :ledger_operations, non_null(list_of(non_null(:ledger_operation))) do
      arg :environment_id, non_null(:id)
      arg :kind, :string
      arg :state, :string
      arg :txid, :string
      arg :limit, :integer, default_value: 100
      middleware Authorize, {:"ledger.read", :environment_id}
      resolve fn args, _ -> {:ok, Ledger.operations(args.environment_id, Map.to_list(args))} end
    end

    field :customer_balances, non_null(list_of(non_null(:customer_balance))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"reconciliation.read", :environment_id}
      resolve fn args, _ -> {:ok, Ledger.customer_balances(args.environment_id)} end
    end

    field :ledger_invariants, non_null(:ledger_invariants) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"ledger.read", :environment_id}

      resolve fn args, _ ->
        {:ok,
         Ledger.verify_invariants(args.environment_id)
         |> Map.put(:duplicate_credits, Ledger.duplicate_credits(args.environment_id))}
      end
    end

    field :financial_rules, non_null(list_of(non_null(:financial_rule))) do
      resolve fn _, _ -> {:ok, Rules.all()} end
    end

    field :operation_timeline, non_null(:operation_timeline) do
      arg :environment_id, non_null(:id)
      arg :operation_id, non_null(:string)
      middleware Authorize, {:"reconciliation.read", :environment_id}
      resolve fn args, _ -> {:ok, Ledger.timeline(args.environment_id, args.operation_id)} end
    end

    field :reconciliation_runs, non_null(list_of(non_null(:reconciliation_run))) do
      arg :environment_id, non_null(:id)
      arg :limit, :integer, default_value: 30
      middleware Authorize, {:"reconciliation.read", :environment_id}
      resolve fn args, _ -> {:ok, Reconciliation.list_runs(args.environment_id, min(args.limit, 200))} end
    end

    field :reconciliation_run, :reconciliation_run do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = run <- Reconciliation.get_run(id),
             :ok <- authorize_env(res, :"reconciliation.read", run.environment_id) do
          {:ok, run}
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :discrepancies, non_null(list_of(non_null(:discrepancy))) do
      arg :environment_id, non_null(:id)
      arg :states, list_of(non_null(:string))
      arg :kind, :string
      arg :limit, :integer, default_value: 100
      middleware Authorize, {:"reconciliation.read", :environment_id}
      resolve fn args, _ -> {:ok, Reconciliation.list_discrepancies(args.environment_id, Map.to_list(args))} end
    end

    field :discrepancy, :discrepancy do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = d <- Reconciliation.get_discrepancy(id),
             :ok <- authorize_env(res, :"reconciliation.read", d.environment_id) do
          {:ok, d}
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end
  end

  object :finance_mutations do
    field :request_withdrawal, :posting_result do
      arg :environment_id, non_null(:id)
      arg :account_ref, non_null(:string)
      arg :amount_sats, non_null(:sats)
      arg :fee_sats, :sats, default_value: 0
      arg :idempotency_key, non_null(:string)
      middleware Authorize, {:"ledger.post", :environment_id}

      resolve fn a, res ->
        with {:ok, j, status} <-
               Ledger.request_withdrawal(
                 a.environment_id,
                 a.account_ref,
                 a.amount_sats,
                 a.fee_sats,
                 a.idempotency_key,
                 actor(res)
               ) do
          {:ok, %{journal: Ledger.get_journal!(j.id), status: to_string(status)}}
        end
      end
    end

    field :settle_withdrawal, :posting_result do
      arg :environment_id, non_null(:id)
      arg :idempotency_key, non_null(:string)
      arg :outcome, non_null(:string)
      arg :txid, :string
      arg :reason, :string
      middleware Authorize, {:"ledger.post", :environment_id}

      resolve fn a, res ->
        outcome = if a.outcome == "confirmed", do: :confirmed, else: :failed

        with {:ok, j, status} <-
               Ledger.settle_withdrawal(
                 a.environment_id,
                 a.idempotency_key,
                 outcome,
                 %{txid: a[:txid], reason: a[:reason]},
                 actor(res)
               ) do
          {:ok, %{journal: Ledger.get_journal!(j.id), status: to_string(status)}}
        end
      end
    end

    field :internal_transfer, :posting_result do
      arg :environment_id, non_null(:id)
      arg :from_ref, non_null(:string)
      arg :to_ref, non_null(:string)
      arg :amount_sats, non_null(:sats)
      arg :idempotency_key, non_null(:string)
      middleware Authorize, {:"ledger.post", :environment_id}

      resolve fn a, res ->
        with {:ok, j, status} <-
               Ledger.transfer(a.environment_id, a.from_ref, a.to_ref, a.amount_sats, a.idempotency_key, actor(res)) do
          {:ok, %{journal: Ledger.get_journal!(j.id), status: to_string(status)}}
        end
      end
    end

    field :compensate_journal, :posting_result do
      arg :environment_id, non_null(:id)
      arg :journal_id, non_null(:id)
      arg :reason, non_null(:string)
      middleware Authorize, {:"ledger.compensate", :environment_id}

      resolve fn a, res ->
        with {:ok, j, status} <- Ledger.compensate(a.environment_id, a.journal_id, a.reason, actor(res)) do
          {:ok, %{journal: Ledger.get_journal!(j.id), status: to_string(status)}}
        end
      end
    end

    field :run_reconciliation, :reconciliation_run do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"reconciliation.run", :environment_id}
      resolve fn a, res -> Reconciliation.enqueue(a.environment_id, "manual", actor(res)) end
    end

    field :transition_discrepancy, :discrepancy do
      arg :id, non_null(:id)
      arg :state, non_null(:string)
      arg :note, :string

      resolve fn a, res ->
        with %{} = d <- Reconciliation.get_discrepancy(a.id),
             :ok <- authorize_env(res, :"discrepancy.resolve", d.environment_id) do
          Reconciliation.transition(d, a.state, a[:note], actor(res))
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :add_discrepancy_note, :discrepancy_note do
      arg :id, non_null(:id)
      arg :body, non_null(:string)
      arg :kind, :string, default_value: "note"
      arg :data, :json

      resolve fn a, res ->
        with %{} = d <- Reconciliation.get_discrepancy(a.id),
             :ok <- authorize_env(res, :"discrepancy.resolve", d.environment_id) do
          Reconciliation.add_note(d, String.slice(a.body, 0, 4000), a.kind, a[:data], actor(res))
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end
  end
end
