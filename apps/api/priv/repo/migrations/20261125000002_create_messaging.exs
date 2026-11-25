defmodule SatOps.Repo.Migrations.CreateMessaging do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 14)

    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :seq, :bigserial, null: false
      add :event_type, :text, null: false
      add :schema_version, :integer, null: false, default: 1
      add :environment_id, :binary_id, null: false
      add :network_id, :text
      add :aggregate_type, :text, null: false
      add :aggregate_id, :text, null: false
      add :aggregate_version, :integer
      add :occurred_at, :utc_datetime_usec, null: false
      add :observed_at, :utc_datetime_usec, null: false
      add :correlation_id, :binary_id, null: false
      add :causation_id, :binary_id
      add :dedupe_key, :text
      add :payload, :map, null: false, default: %{}
    end

    create unique_index(:events, [:seq])
    create unique_index(:events, [:environment_id, :dedupe_key])
    create index(:events, [:environment_id, :event_type, :seq])
    create index(:events, [:environment_id, :aggregate_type, :aggregate_id, :seq])
    create index(:events, [:correlation_id])

    execute """
    CREATE TRIGGER events_append_only BEFORE UPDATE OR DELETE ON events
    FOR EACH ROW EXECUTE FUNCTION satops_forbid_mutation()
    """

    create table(:consumer_checkpoints, primary_key: false) do
      add :consumer, :text, primary_key: true
      add :last_seq, :bigint, null: false, default: 0
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create table(:processed_events, primary_key: false) do
      add :consumer, :text, primary_key: true
      add :event_id, :binary_id, primary_key: true
      add :processed_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end
  end

  def down do
    drop table(:processed_events)
    drop table(:consumer_checkpoints)
    drop table(:events)
    Oban.Migration.down(version: 1)
  end
end
