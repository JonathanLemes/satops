defmodule SatOps.Repo.Migrations.CreatePlatform do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :name, :text, null: false
      add :password_hash, :text, null: false
      add :role, :text, null: false
      add :locale, :text, null: false, default: "en"
      add :disabled_at, :utc_datetime_usec
      timestamps()
    end

    create unique_index(:users, [:email])

    create constraint(:users, :users_role_check,
             check: "role IN ('administrator','engineer','auditor','viewer')"
           )

    create table(:user_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :csrf_token, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :ip, :text
      add :user_agent, :text
      timestamps(updated_at: false)
    end

    create unique_index(:user_sessions, [:token_hash])
    create index(:user_sessions, [:expires_at])

    create table(:environments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :text, null: false
      add :name, :text, null: false
      add :kind, :text, null: false, default: "persistent"
      add :network, :text, null: false, default: "regtest"
      add :status, :text, null: false, default: "active"
      add :required_confirmations, :integer, null: false, default: 3
      add :settings, :map, null: false, default: %{}
      add :expires_at, :utc_datetime_usec
      timestamps()
    end

    create unique_index(:environments, [:slug])
    create constraint(:environments, :environments_network_regtest, check: "network = 'regtest'")

    create constraint(:environments, :environments_kind_check,
             check: "kind IN ('persistent','ephemeral')"
           )

    create constraint(:environments, :environments_confirmations_check,
             check: "required_confirmations BETWEEN 1 AND 100"
           )

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :role, :text, null: false
      timestamps()
    end

    create unique_index(:memberships, [:user_id, :environment_id])

    create constraint(:memberships, :memberships_role_check,
             check: "role IN ('administrator','engineer','auditor','viewer')"
           )

    create table(:secrets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all)
      add :name, :text, null: false
      add :ciphertext, :binary, null: false
      timestamps()
    end

    create unique_index(:secrets, [:environment_id, :name], nulls_distinct: false)

    create table(:integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :text, null: false
      add :kind, :text, null: false
      add :config, :map, null: false, default: %{}
      add :secret_ref, :text
      add :enabled, :boolean, null: false, default: true
      add :status, :text, null: false, default: "unknown"
      add :health, :map, null: false, default: %{}
      add :capabilities, {:array, :text}, null: false, default: []
      add :enabled_operations, {:array, :text}, null: false, default: []
      add :retry, :map, null: false, default: %{}
      add :checkpoint, :map, null: false, default: %{}
      add :last_sync_at, :utc_datetime_usec
      add :last_error, :text
      add :lock_version, :integer, null: false, default: 1
      timestamps()
    end

    create unique_index(:integrations, [:environment_id, :name])
    create index(:integrations, [:kind])

    create constraint(:integrations, :integrations_kind_check,
             check:
               "kind IN ('bitcoin_core','demo_fintech','generic_rest','csv_import','webhook_receiver','webhook_destination','kubernetes')"
           )

    create table(:integration_errors) do
      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :message, :text, null: false
      add :occurred_at, :utc_datetime_usec, null: false
    end

    create index(:integration_errors, [:integration_id, :occurred_at])

    create table(:audit_entries) do
      add :actor_id, :binary_id
      add :actor_email, :text
      add :action, :text, null: false
      add :environment_id, :binary_id
      add :resource_type, :text
      add :resource_id, :text
      add :changes, :map, null: false, default: %{}
      add :ip, :text
      add :correlation_id, :binary_id
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:audit_entries, [:environment_id, :inserted_at])
    create index(:audit_entries, [:resource_type, :resource_id])

    execute """
            CREATE FUNCTION satops_forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN
              RAISE EXCEPTION 'append-only table %: % is not allowed', TG_TABLE_NAME, TG_OP
                USING ERRCODE = 'integrity_constraint_violation';
            END $$;
            """,
            "DROP FUNCTION satops_forbid_mutation()"

    execute """
            CREATE TRIGGER audit_entries_append_only BEFORE UPDATE OR DELETE ON audit_entries
            FOR EACH ROW EXECUTE FUNCTION satops_forbid_mutation()
            """,
            "DROP TRIGGER audit_entries_append_only ON audit_entries"
  end
end
