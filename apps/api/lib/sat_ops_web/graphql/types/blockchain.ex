defmodule SatOpsWeb.GraphQL.Types.Blockchain do
  use Absinthe.Schema.Notation
  import SatOpsWeb.GraphQL.Helpers
  alias SatOps.{Blockchain, Environments, Ledger, Repo, WalletMonitoring}
  alias SatOpsWeb.GraphQL.Authorize

  object :block do
    field :hash, non_null(:string)
    field :height, non_null(:integer)
    field :prev_hash, :string
    field :chainwork, :string, resolve: fn b, _, _ -> {:ok, b.chainwork && Decimal.to_string(b.chainwork)} end
    field :block_time, :datetime
    field :tx_count, non_null(:integer)
    field :in_best_chain, non_null(:boolean)
    field :connected_at, :datetime
    field :disconnected_at, :datetime
  end

  object :node_observation do
    field :observed_at, non_null(:datetime)
    field :reachable, non_null(:boolean)
    field :chain, :string
    field :height, :integer
    field :best_hash, :string
    field :chainwork, :string, resolve: fn o, _, _ -> {:ok, o.chainwork && Decimal.to_string(o.chainwork)} end
    field :initial_block_download, :boolean
    field :peers, :integer
    field :mempool_size, :integer
    field :rpc_latency_ms, :integer
    field :error, :string
  end

  object :zmq_checkpoint do
    field :last_sequence, :integer
    field :gaps_total, non_null(:integer)
    field :duplicates_total, non_null(:integer)
    field :updated_at, :datetime
  end

  object :node_status do
    field :integration, non_null(:integration)
    field :latest, :node_observation
    field :is_reference, non_null(:boolean)

    field :history, non_null(list_of(non_null(:node_observation))) do
      arg :limit, :integer, default_value: 60
      resolve fn n, args, _ -> {:ok, Blockchain.node_history(n.integration.id, min(args.limit, 500))} end
    end

    field :downtime, non_null(list_of(non_null(:domain_event))) do
      resolve fn n, _, _ -> {:ok, Blockchain.downtime(n.integration.id)} end
    end

    field :zmq, :zmq_checkpoint do
      resolve fn n, _, _ -> {:ok, Blockchain.zmq_checkpoint(n.integration.id)} end
    end
  end

  object :chain_overview do
    field :tip, :block
    field :checkpoint_height, :integer
    field :checkpoint_hash, :string
    field :checkpoint_updated_at, :datetime
    field :mempool_size, non_null(:integer)
    field :transaction_counts, :json
    field :diverged, non_null(:boolean)
    field :reference_node, :string
    field :required_confirmations, non_null(:integer)
    field :reorganizations, non_null(list_of(non_null(:domain_event)))
    field :stale_blocks, non_null(list_of(non_null(:block)))
  end

  object :tx_output do
    field :vout, non_null(:integer)
    field :value_sats, non_null(:sats)
    field :address, :string
    field :script_type, :string
    field :spent_by_txid, :string
    field :watched, :json
  end

  object :tx_input do
    field :vin, non_null(:integer)
    field :prev_txid, :string
    field :prev_vout, :integer
    field :value_sats, :sats
    field :address, :string
    field :watched, :json
  end

  object :status_change do
    field :from_status, :string
    field :to_status, non_null(:string)
    field :block_hash, :string
    field :block_height, :integer
    field :reason, :string
    field :event_id, :id
    field :inserted_at, non_null(:datetime)
  end

  object :transaction do
    field :id, non_null(:id)
    field :environment_id, non_null(:id)
    field :txid, non_null(:string)
    field :status, non_null(:string)
    field :block_hash, :string
    field :block_height, :integer
    field :fee_sats, :sats
    field :vsize, :integer
    field :is_coinbase, non_null(:boolean)
    field :replaced_by_txid, :string
    field :conflicts_with, list_of(:string)
    field :first_seen_at, non_null(:datetime)
    field :status_changed_at, non_null(:datetime)

    field :confirmations, non_null(:integer) do
      resolve fn tx, _, _ -> {:ok, Blockchain.confirmations(tx.environment_id, tx)} end
    end

    field :total_out_sats, :sats do
      resolve fn tx, _, _ ->
        {:ok, Blockchain.outputs(tx.environment_id, tx.txid) |> Enum.map(& &1.value_sats) |> Enum.sum()}
      end
    end

    field :outputs, non_null(list_of(non_null(:tx_output))) do
      resolve fn tx, _, _ ->
        outs = Blockchain.outputs(tx.environment_id, tx.txid)

        watched =
          WalletMonitoring.watched_address_map(
            tx.environment_id,
            outs |> Enum.map(& &1.address) |> Enum.reject(&is_nil/1)
          )

        {:ok, Enum.map(outs, &Map.put(&1, :watched, Map.get(watched, &1.address)))}
      end
    end

    field :inputs, non_null(list_of(non_null(:tx_input))) do
      resolve fn tx, _, _ ->
        ins = Blockchain.inputs(tx.environment_id, tx.txid)

        watched =
          WalletMonitoring.watched_address_map(
            tx.environment_id,
            ins |> Enum.map(& &1.address) |> Enum.reject(&is_nil/1)
          )

        {:ok, Enum.map(ins, &Map.put(&1, :watched, Map.get(watched, &1.address)))}
      end
    end

    field :status_history, non_null(list_of(non_null(:status_change))) do
      resolve fn tx, _, _ -> {:ok, Blockchain.status_history(tx.environment_id, tx.txid)} end
    end

    field :events, non_null(list_of(non_null(:domain_event))) do
      resolve fn tx, _, _ -> {:ok, SatOps.Events.list(tx.environment_id, aggregate_id: tx.txid, limit: 100)} end
    end

    field :operations, non_null(list_of(non_null(:ledger_operation))) do
      resolve fn tx, _, _ -> {:ok, Ledger.operations(tx.environment_id, txid: tx.txid)} end
    end

    field :reconciliation_status, :string do
      resolve fn tx, _, _ ->
        import Ecto.Query

        state =
          Repo.one(
            from i in SatOps.Reconciliation.Item,
              join: r in SatOps.Reconciliation.Run,
              on: r.id == i.run_id,
              where: i.environment_id == ^tx.environment_id and i.txid == ^tx.txid,
              order_by: [desc: r.inserted_at, desc: fragment("CASE WHEN ? = 'discrepancy' THEN 1 ELSE 0 END", i.state)],
              limit: 1,
              select: i.state
          )

        {:ok, state}
      end
    end
  end

  object :page_info do
    field :end_cursor, :string
    field :has_next_page, non_null(:boolean)
  end

  object :transaction_connection do
    field :nodes, non_null(list_of(non_null(:transaction)))
    field :page_info, non_null(:page_info)
  end

  input_object :transaction_filter do
    field :status, :string
    field :search, :string
    field :address, :string
    field :watched_only, :boolean
    field :include_coinbase, :boolean
  end

  object :watched_address do
    field :address, non_null(:string)
    field :label, :string
    field :derivation_index, :integer
  end

  object :balance do
    field :confirmed_sats, non_null(:sats)
    field :pending_sats, non_null(:sats)
    field :utxo_count, non_null(:integer)
  end

  object :wallet do
    field :id, non_null(:id)
    field :environment_id, non_null(:id)
    field :name, non_null(:string)
    field :kind, non_null(:string)
    field :descriptor, :string
    field :derivation_limit, non_null(:integer)
    field :group_name, :string
    field :labels, non_null(list_of(non_null(:string)))
    field :account_ref, :string
    field :addresses, non_null(list_of(non_null(:watched_address)))

    field :balance, non_null(:balance) do
      resolve fn w, _, _ ->
        env = Environments.get!(w.environment_id)
        {:ok, WalletMonitoring.balance(w.environment_id, env.required_confirmations, [w.id])}
      end
    end
  end

  object :utxo do
    field :txid, non_null(:string)
    field :vout, non_null(:integer)
    field :address, :string
    field :value_sats, non_null(:sats)
    field :status, non_null(:string)
    field :block_height, :integer
    field :spent_unconfirmed, non_null(:boolean)
  end

  object :wallet_history_entry do
    field :txid, non_null(:string)
    field :status, non_null(:string)
    field :block_height, :integer
    field :first_seen_at, :datetime
    field :received_sats, non_null(:sats)
    field :sent_sats, non_null(:sats)
  end

  object :internal_transfer do
    field :txid, non_null(:string)
    field :from_wallet_id, non_null(:id)
    field :to_wallet_id, non_null(:id)
    field :value_sats, non_null(:sats)
  end

  object :portfolio do
    field :balance, non_null(:balance)
    field :wallet_count, non_null(:integer)
    field :utxos, non_null(list_of(non_null(:utxo)))
    field :history, non_null(list_of(non_null(:wallet_history_entry)))
    field :internal_transfers, non_null(list_of(non_null(:internal_transfer)))
  end

  object :volume_bucket do
    field :bucket, non_null(:datetime)
    field :count, non_null(:integer)
    field :value_sats, non_null(:sats)
  end

  input_object :wallet_input do
    field :name, non_null(:string)
    field :kind, non_null(:string)
    field :descriptor, :string
    field :derivation_limit, :integer
    field :group_name, :string
    field :labels, list_of(non_null(:string))
    field :account_ref, :string
    field :addresses, list_of(non_null(:string))
  end

  object :blockchain_queries do
    field :nodes, non_null(list_of(non_null(:node_status))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"blockchain.read", :environment_id}

      resolve fn %{environment_id: env}, _ ->
        reference =
          case Blockchain.reference_node(env) do
            {:ok, i} -> i.id
            _ -> nil
          end

        {:ok,
         Blockchain.latest_observations(env)
         |> Enum.map(fn {i, o} -> %{integration: i, latest: o, is_reference: i.id == reference} end)}
      end
    end

    field :chain_overview, non_null(:chain_overview) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"blockchain.read", :environment_id}

      resolve fn %{environment_id: env_id}, _ ->
        env = Environments.get!(env_id)
        cp = Blockchain.chain_checkpoint(env_id) || %{}
        obs = Blockchain.latest_observations(env_id)
        reachable = for {_i, o} <- obs, o && o.reachable, do: o

        reference =
          case Blockchain.reference_node(env_id) do
            {:ok, i} -> i.name
            _ -> nil
          end

        {:ok,
         %{
           tip: Blockchain.tip(env_id),
           checkpoint_height: cp[:tip_height],
           checkpoint_hash: cp[:tip_hash],
           checkpoint_updated_at: cp[:updated_at],
           mempool_size: Blockchain.mempool_size(env_id),
           transaction_counts: Blockchain.tx_counts(env_id),
           diverged: SatOps.Blockchain.ForkFinder.divergent?(reachable),
           reference_node: reference,
           required_confirmations: env.required_confirmations,
           reorganizations: Blockchain.reorganizations(env_id, 10),
           stale_blocks: Blockchain.stale_blocks(env_id, 10)
         }}
      end
    end

    field :blocks, non_null(list_of(non_null(:block))) do
      arg :environment_id, non_null(:id)
      arg :before_height, :integer
      arg :limit, :integer, default_value: 20
      arg :include_stale, :boolean, default_value: false
      middleware Authorize, {:"blockchain.read", :environment_id}
      resolve fn args, _ -> {:ok, Blockchain.blocks(args.environment_id, Map.to_list(args))} end
    end

    field :transactions, non_null(:transaction_connection) do
      arg :environment_id, non_null(:id)
      arg :filter, :transaction_filter
      arg :first, :integer, default_value: 25
      arg :after, :string
      middleware Authorize, {:"blockchain.read", :environment_id}

      resolve fn args, _ ->
        after_id =
          case args[:after] && Base.url_decode64(args.after, padding: false) do
            {:ok, s} -> String.to_integer(s)
            _ -> nil
          end

        {rows, more} =
          Blockchain.list_transactions(args.environment_id, args[:filter] || %{}, %{first: args.first, after: after_id})

        last = List.last(rows)

        {:ok,
         %{
           nodes: rows,
           page_info: %{
             has_next_page: more,
             end_cursor: last && Base.url_encode64(Integer.to_string(last.id), padding: false)
           }
         }}
      end
    end

    field :transaction, :transaction do
      arg :environment_id, non_null(:id)
      arg :txid, non_null(:string)
      middleware Authorize, {:"blockchain.read", :environment_id}
      resolve fn args, _ -> {:ok, Blockchain.get_transaction(args.environment_id, args.txid)} end
    end

    field :transaction_volume, non_null(list_of(non_null(:volume_bucket))) do
      arg :environment_id, non_null(:id)
      arg :hours, :integer, default_value: 24
      middleware Authorize, {:"blockchain.read", :environment_id}
      resolve fn args, _ -> {:ok, Blockchain.transaction_volume(args.environment_id, min(args.hours, 24 * 14))} end
    end

    field :wallets, non_null(list_of(non_null(:wallet))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"wallet.read", :environment_id}
      resolve fn args, _ -> {:ok, WalletMonitoring.list_wallets(args.environment_id)} end
    end

    field :portfolio, non_null(:portfolio) do
      arg :environment_id, non_null(:id)
      arg :wallet_ids, list_of(non_null(:id))
      middleware Authorize, {:"wallet.read", :environment_id}

      resolve fn args, _ ->
        env = Environments.get!(args.environment_id)
        ids = args[:wallet_ids]

        {:ok,
         %{
           balance: WalletMonitoring.balance(env.id, env.required_confirmations, ids),
           wallet_count: length(WalletMonitoring.list_wallets(env.id)),
           utxos: WalletMonitoring.utxos(env.id, ids),
           history: WalletMonitoring.history(env.id, ids, 100),
           internal_transfers: WalletMonitoring.internal_transfers(env.id)
         }}
      end
    end
  end

  object :blockchain_mutations do
    field :create_wallet, :wallet do
      arg :environment_id, non_null(:id)
      arg :input, non_null(:wallet_input)
      middleware Authorize, {:"wallet.manage", :environment_id}

      resolve fn %{environment_id: env, input: input}, res ->
        WalletMonitoring.create_wallet(Map.put(input, :environment_id, env), actor(res))
      end
    end

    field :add_watched_address, :wallet do
      arg :wallet_id, non_null(:id)
      arg :address, non_null(:string)
      arg :label, :string

      resolve fn args, res ->
        with %{} = w <- WalletMonitoring.get_wallet(args.wallet_id),
             :ok <- authorize_env(res, :"wallet.manage", w.environment_id) do
          WalletMonitoring.add_address(w, args.address, args[:label], actor(res))
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :delete_wallet, :boolean do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = w <- WalletMonitoring.get_wallet(id),
             :ok <- authorize_env(res, :"wallet.manage", w.environment_id),
             {:ok, _} <- WalletMonitoring.delete_wallet(w, actor(res)) do
          {:ok, true}
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :sync_chain, :boolean do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"integration.manage", :environment_id}

      resolve fn args, _ ->
        SatOps.Blockchain.Workers.SyncChain.enqueue(args.environment_id, "manual")
        {:ok, true}
      end
    end
  end
end
