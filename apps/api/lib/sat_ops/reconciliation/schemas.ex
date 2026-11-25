defmodule SatOps.Reconciliation.Run do
  use SatOps.Schema

  schema "reconciliation_runs" do
    field :environment_id, :binary_id
    field :policy_name, :string
    field :policy_version, :integer
    field :policy, :map, default: %{}
    field :status, :string
    field :completeness, :string, default: "unknown"
    field :trigger, :string, default: "manual"
    field :reference_height, :integer
    field :reference_hash, :string
    field :sources, {:array, :map}, default: []
    field :summary, :map, default: %{}
    field :error, :string
    field :correlation_id, :binary_id
    field :requested_by, :binary_id
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    timestamps()
  end
end

defmodule SatOps.Reconciliation.Item do
  use Ecto.Schema

  schema "reconciliation_items" do
    field :run_id, :binary_id
    field :environment_id, :binary_id
    field :match_key, :string
    field :state, :string
    field :discrepancy_kind, :string
    field :reason, :string
    field :records, {:array, :map}, default: []
    field :amount_sats, :integer
    field :txid, :string
    field :vout, :integer
  end
end

defmodule SatOps.Reconciliation.Discrepancy do
  use SatOps.Schema

  schema "discrepancies" do
    field :environment_id, :binary_id
    field :fingerprint, :string
    field :kind, :string
    field :state, :string, default: "open"
    field :severity, :string, default: "high"
    field :match_key, :string
    field :txid, :string
    field :vout, :integer
    field :amount_sats, :integer
    field :reason, :string
    field :evidence, :map, default: %{}
    field :first_run_id, :binary_id
    field :last_run_id, :binary_id
    field :occurrences, :integer, default: 1
    field :resolution, :string
    field :resolved_by, :binary_id
    field :resolved_at, :utc_datetime_usec
    field :lock_version, :integer, default: 1
    has_many :notes, SatOps.Reconciliation.Note
    timestamps()
  end
end

defmodule SatOps.Reconciliation.Note do
  use Ecto.Schema

  schema "discrepancy_notes" do
    belongs_to :discrepancy, SatOps.Reconciliation.Discrepancy, type: :binary_id
    field :author_id, :binary_id
    field :author_email, :string
    field :kind, :string, default: "note"
    field :body, :string
    field :data, :map, default: %{}
    field :inserted_at, :utc_datetime_usec
  end
end
