defmodule SatOps.Repo.Migrations.CreateConfigurationDashboardsAlerts do
  use Ecto.Migration

  def change do
    create table(:config_resources, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :text, null: false
      add :name, :text, null: false
      add :environment_ref, :text
      add :desired_revision, :integer, null: false
      add :applied_revision, :integer
      add :status, :text, null: false, default: "pending"
      add :observed, :map, null: false, default: %{}
      add :status_message, :text
      add :lock_version, :integer, null: false, default: 1
      add :deleted_at, :utc_datetime_usec
      timestamps()
    end

    create unique_index(:config_resources, [:kind, :name])

    create table(:config_revisions) do
      add :resource_id, references(:config_resources, type: :binary_id, on_delete: :delete_all),
        null: false

      add :revision, :integer, null: false
      add :api_version, :text, null: false
      add :spec, :map, null: false
      add :spec_hash, :text, null: false
      add :yaml, :text, null: false
      add :author_id, :binary_id
      add :author_email, :text
      add :message, :text
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:config_revisions, [:resource_id, :revision])

    create table(:dashboards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all)
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :name, :text, null: false
      add :title, :text, null: false
      add :workspace, :text, null: false
      add :spec, :map, null: false
      add :is_default, :boolean, null: false, default: false
      add :lock_version, :integer, null: false, default: 1
      timestamps()
    end

    create unique_index(:dashboards, [:owner_id, :name], nulls_distinct: false)

    create constraint(:dashboards, :dashboards_workspace_check,
             check: "workspace IN ('customer','engineering')"
           )

    create table(:alert_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :text, null: false
      add :event_types, {:array, :text}, null: false
      add :severity, :text, null: false, default: "warning"
      add :cooldown_seconds, :integer, null: false, default: 300
      add :destinations, {:array, :map}, null: false, default: []
      add :enabled, :boolean, null: false, default: true
      timestamps()
    end

    create unique_index(:alert_policies, [:environment_id, :name])

    create table(:alert_occurrences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :environment_id, :binary_id, null: false

      add :policy_id, references(:alert_policies, type: :binary_id, on_delete: :delete_all),
        null: false

      add :fingerprint, :text, null: false
      add :state, :text, null: false, default: "firing"
      add :severity, :text, null: false
      add :title, :text, null: false
      add :details, :map, null: false, default: %{}
      add :first_event_id, :binary_id
      add :last_event_id, :binary_id
      add :count, :integer, null: false, default: 1
      add :first_seen_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :last_notified_at, :utc_datetime_usec
      add :acknowledged_by, :binary_id
      add :resolved_at, :utc_datetime_usec
      timestamps()
    end

    create unique_index(:alert_occurrences, [:policy_id, :fingerprint],
             where: "state IN ('firing','acknowledged')",
             name: :alert_occurrences_one_active
           )

    create index(:alert_occurrences, [:environment_id, :state, :last_seen_at])

    create table(:alert_deliveries) do
      add :occurrence_id,
          references(:alert_occurrences, type: :binary_id, on_delete: :delete_all),
          null: false

      add :destination, :text, null: false
      add :kind, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :last_error, :text
      add :response_status, :integer
      add :delivered_at, :utc_datetime_usec
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:alert_deliveries, [:occurrence_id])

    create constraint(:alert_deliveries, :alert_deliveries_status_check,
             check: "status IN ('pending','delivered','failed','failed_terminal')"
           )
  end
end
