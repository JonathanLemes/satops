defmodule SatOps.Configuration.Resource do
  use SatOps.Schema

  schema "config_resources" do
    field :kind, :string
    field :name, :string
    field :environment_ref, :string
    field :desired_revision, :integer
    field :applied_revision, :integer
    field :status, :string, default: "pending"
    field :observed, :map, default: %{}
    field :status_message, :string
    field :lock_version, :integer, default: 1
    field :deleted_at, :utc_datetime_usec
    timestamps()
  end
end

defmodule SatOps.Configuration.Revision do
  use Ecto.Schema

  schema "config_revisions" do
    field :resource_id, :binary_id
    field :revision, :integer
    field :api_version, :string
    field :spec, :map
    field :spec_hash, :string
    field :yaml, :string
    field :author_id, :binary_id
    field :author_email, :string
    field :message, :string
    field :inserted_at, :utc_datetime_usec
  end
end

defmodule SatOps.Configuration.Workers.Reconcile do
  use Oban.Worker, queue: :maintenance, max_attempts: 1, unique: [period: 50]

  @impl true
  def perform(_job), do: SatOps.Configuration.reconcile_all()
end
