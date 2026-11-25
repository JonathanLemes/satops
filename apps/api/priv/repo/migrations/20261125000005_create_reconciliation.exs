defmodule SatOps.Repo.Migrations.CreateReconciliation do
  use Ecto.Migration

  def change do
    create table(:reconciliation_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :policy_name, :text, null: false
      add :policy_version, :integer, null: false
      add :policy, :map, null: false, default: %{}
      add :status, :text, null: false
      add :completeness, :text, null: false, default: "unknown"
      add :trigger, :text, null: false, default: "manual"
      add :reference_height, :integer
      add :reference_hash, :text
      add :sources, {:array, :map}, null: false, default: []
      add :summary, :map, null: false, default: %{}
      add :error, :text
      add :correlation_id, :binary_id
      add :requested_by, :binary_id
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      timestamps()
    end

    create index(:reconciliation_runs, [:environment_id, :inserted_at])

    create constraint(:reconciliation_runs, :reconciliation_runs_status_check,
             check: "status IN ('queued','running','completed','incomplete','failed')"
           )

    create table(:reconciliation_items) do
      add :run_id, references(:reconciliation_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :environment_id, :binary_id, null: false
      add :match_key, :text, null: false
      add :state, :text, null: false
      add :discrepancy_kind, :text
      add :reason, :text, null: false
      add :records, {:array, :map}, null: false, default: []
      add :amount_sats, :bigint
      add :txid, :text
      add :vout, :integer
    end

    create index(:reconciliation_items, [:run_id, :state])
    create index(:reconciliation_items, [:environment_id, :txid])

    create constraint(:reconciliation_items, :reconciliation_items_state_check,
             check:
               "state IN ('matched','pending','unmatched','discrepancy','ambiguous','resolved','ignored')"
           )

    create table(:discrepancies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :fingerprint, :text, null: false
      add :kind, :text, null: false
      add :state, :text, null: false, default: "open"
      add :severity, :text, null: false, default: "high"
      add :match_key, :text, null: false
      add :txid, :text
      add :vout, :integer
      add :amount_sats, :bigint
      add :reason, :text, null: false
      add :evidence, :map, null: false, default: %{}
      add :first_run_id, :binary_id, null: false
      add :last_run_id, :binary_id, null: false
      add :occurrences, :integer, null: false, default: 1
      add :resolution, :text
      add :resolved_by, :binary_id
      add :resolved_at, :utc_datetime_usec
      add :lock_version, :integer, null: false, default: 1
      timestamps()
    end

    create unique_index(:discrepancies, [:environment_id, :fingerprint],
             where: "state IN ('open','investigating')",
             name: :discrepancies_one_active_per_fingerprint
           )

    create index(:discrepancies, [:environment_id, :state])

    create constraint(:discrepancies, :discrepancies_state_check,
             check: "state IN ('open','investigating','resolved','ignored')"
           )

    create table(:discrepancy_notes) do
      add :discrepancy_id, references(:discrepancies, type: :binary_id, on_delete: :delete_all),
        null: false

      add :author_id, :binary_id
      add :author_email, :text
      add :kind, :text, null: false, default: "note"
      add :body, :text, null: false
      add :data, :map, null: false, default: %{}
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:discrepancy_notes, [:discrepancy_id, :inserted_at])

    create table(:external_records) do
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :source_record_id, :text, null: false
      add :kind, :text, null: false
      add :account_ref, :text
      add :asset, :text, null: false, default: "BTC"
      add :amount_sats, :bigint, null: false
      add :txid, :text
      add :vout, :integer
      add :status, :text, null: false
      add :occurred_at, :utc_datetime_usec
      add :raw, :map, null: false, default: %{}
      add :received_via, :text, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:external_records, [:integration_id, :source_record_id])
    create index(:external_records, [:environment_id, :txid])

    create table(:webhook_receipts) do
      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :delivery_id, :text, null: false
      add :signature_valid, :boolean, null: false
      add :payload_sha256, :text, null: false
      add :received_at, :utc_datetime_usec, null: false
    end

    create unique_index(:webhook_receipts, [:integration_id, :delivery_id])
  end
end
