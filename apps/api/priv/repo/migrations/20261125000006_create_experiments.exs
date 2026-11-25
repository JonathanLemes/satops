defmodule SatOps.Repo.Migrations.CreateExperiments do
  use Ecto.Migration

  def change do
    create table(:scenarios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :version, :integer, null: false
      add :title, :text, null: false
      add :description, :text
      add :guarantee, :text
      add :required_capabilities, {:array, :text}, null: false, default: []
      add :spec, :map, null: false
      add :source_yaml, :text
      timestamps()
    end

    create unique_index(:scenarios, [:name, :version])

    create table(:experiment_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :scenario_id, references(:scenarios, type: :binary_id, on_delete: :restrict),
        null: false

      add :scenario_name, :text, null: false
      add :scenario_version, :integer, null: false
      add :status, :text, null: false
      add :seed, :bigint, null: false
      add :params, :map, null: false, default: %{}
      add :status_reason, :text
      add :cleanup_status, :text, null: false, default: "pending"
      add :lease_owner, :text
      add :lease_expires_at, :utc_datetime_usec
      add :correlation_id, :binary_id, null: false
      add :requested_by, :binary_id
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :report, :map
      add :lock_version, :integer, null: false, default: 1
      timestamps()
    end

    create index(:experiment_runs, [:environment_id, :inserted_at])
    create index(:experiment_runs, [:status])

    create constraint(:experiment_runs, :experiment_runs_status_check,
             check:
               "status IN ('created','validating','provisioning','preparing','running','verifying','cleaning_up','passed','failed','inconclusive','aborted')"
           )

    create table(:experiment_steps) do
      add :run_id, references(:experiment_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :position, :integer, null: false
      add :step_key, :text, null: false
      add :phase, :text, null: false
      add :action, :text, null: false
      add :params, :map, null: false, default: %{}
      add :status, :text, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false, default: 1
      add :timeout_ms, :integer, null: false
      add :checkpoint, :map, null: false, default: %{}
      add :result, :map
      add :evidence, :map, null: false, default: %{}
      add :failure_reason, :text
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
    end

    create unique_index(:experiment_steps, [:run_id, :position])
    create unique_index(:experiment_steps, [:run_id, :step_key])

    create constraint(:experiment_steps, :experiment_steps_status_check,
             check: "status IN ('pending','running','succeeded','failed','unknown','skipped')"
           )

    create table(:experiment_assertions) do
      add :run_id, references(:experiment_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :position, :integer, null: false
      add :type, :text, null: false
      add :params, :map, null: false, default: %{}
      add :outcome, :text, null: false
      add :expected, :map
      add :actual, :map
      add :message, :text
      add :attempts, :integer, null: false, default: 0
      add :evaluated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:experiment_assertions, [:run_id, :position])

    create constraint(:experiment_assertions, :experiment_assertions_outcome_check,
             check: "outcome IN ('passed','false','timed_out','source_unavailable','error')"
           )

    create table(:experiment_artifacts) do
      add :run_id, references(:experiment_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :kind, :text, null: false
      add :ref, :text, null: false
      add :data, :map, null: false, default: %{}
      add :cleaned_at, :utc_datetime_usec
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:experiment_artifacts, [:run_id, :kind, :ref])
  end
end
