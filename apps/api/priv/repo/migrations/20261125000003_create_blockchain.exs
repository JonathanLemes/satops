defmodule SatOps.Repo.Migrations.CreateBlockchain do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :hash, :text, null: false
      add :height, :integer, null: false
      add :prev_hash, :text
      add :chainwork, :numeric, precision: 78, scale: 0, null: false
      add :block_time, :utc_datetime_usec
      add :tx_count, :integer, null: false, default: 0
      add :in_best_chain, :boolean, null: false, default: true
      add :connected_at, :utc_datetime_usec, null: false
      add :disconnected_at, :utc_datetime_usec
    end

    create unique_index(:blocks, [:environment_id, :hash])

    create unique_index(:blocks, [:environment_id, :height],
             where: "in_best_chain",
             name: :blocks_one_best_block_per_height
           )

    create index(:blocks, [:environment_id, :in_best_chain, :height])

    create table(:node_observations) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :observed_at, :utc_datetime_usec, null: false
      add :reachable, :boolean, null: false
      add :chain, :text
      add :height, :integer
      add :best_hash, :text
      add :chainwork, :numeric, precision: 78, scale: 0
      add :initial_block_download, :boolean
      add :peers, :integer
      add :mempool_size, :integer
      add :rpc_latency_ms, :integer
      add :error, :text
    end

    create index(:node_observations, [:integration_id, :observed_at])

    create table(:chain_checkpoints, primary_key: false) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :tip_hash, :text
      add :tip_height, :integer
      add :reference_integration_id, :binary_id
      add :updated_at, :utc_datetime_usec, null: false
    end

    create table(:zmq_checkpoints, primary_key: false) do
      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :last_sequence, :bigint
      add :gaps_total, :bigint, null: false, default: 0
      add :duplicates_total, :bigint, null: false, default: 0
      add :updated_at, :utc_datetime_usec, null: false
    end

    create table(:transactions) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :txid, :text, null: false
      add :status, :text, null: false
      add :block_hash, :text
      add :block_height, :integer
      add :fee_sats, :bigint
      add :vsize, :integer
      add :is_coinbase, :boolean, null: false, default: false
      add :replaced_by_txid, :text
      add :conflicts_with, {:array, :text}, null: false, default: []
      add :first_seen_at, :utc_datetime_usec, null: false
      add :status_changed_at, :utc_datetime_usec, null: false
      add :version, :integer, null: false, default: 1
    end

    create unique_index(:transactions, [:environment_id, :txid])
    create index(:transactions, [:environment_id, :status])
    create index(:transactions, [:environment_id, :block_hash])
    create index(:transactions, [:environment_id, :first_seen_at])

    create constraint(:transactions, :transactions_status_check,
             check:
               "status IN ('observed','pending','confirmed','unconfirmed','conflicted','replaced','unknown')"
           )

    create table(:tx_outputs) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :txid, :text, null: false
      add :vout, :integer, null: false
      add :value_sats, :bigint, null: false
      add :address, :text
      add :script_type, :text
      add :spent_by_txid, :text
      add :spent_by_vin, :integer
    end

    create unique_index(:tx_outputs, [:environment_id, :txid, :vout])
    create index(:tx_outputs, [:environment_id, :address])
    create constraint(:tx_outputs, :tx_outputs_value_check, check: "value_sats >= 0")

    create table(:tx_inputs) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :txid, :text, null: false
      add :vin, :integer, null: false
      add :prev_txid, :text
      add :prev_vout, :integer
    end

    create unique_index(:tx_inputs, [:environment_id, :txid, :vin])
    create index(:tx_inputs, [:environment_id, :prev_txid, :prev_vout])

    create table(:tx_status_changes) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :txid, :text, null: false
      add :from_status, :text
      add :to_status, :text, null: false
      add :block_hash, :text
      add :block_height, :integer
      add :reason, :text
      add :event_id, :binary_id
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:tx_status_changes, [:environment_id, :txid, :inserted_at])

    create table(:watched_wallets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :text, null: false
      add :kind, :text, null: false, default: "addresses"
      add :descriptor, :text
      add :derivation_limit, :integer, null: false, default: 20
      add :group_name, :text
      add :labels, {:array, :text}, null: false, default: []
      add :account_ref, :text
      timestamps()
    end

    create unique_index(:watched_wallets, [:environment_id, :name])

    create constraint(:watched_wallets, :watched_wallets_kind_check,
             check: "kind IN ('addresses','descriptor')"
           )

    create constraint(:watched_wallets, :watched_wallets_limit_check,
             check: "derivation_limit BETWEEN 1 AND 1000"
           )

    create table(:watched_addresses) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :wallet_id, references(:watched_wallets, type: :binary_id, on_delete: :delete_all),
        null: false

      add :address, :text, null: false
      add :label, :text
      add :derivation_index, :integer
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:watched_addresses, [:wallet_id, :address])
    create index(:watched_addresses, [:environment_id, :address])
  end
end
