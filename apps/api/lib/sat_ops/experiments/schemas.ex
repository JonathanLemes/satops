defmodule SatOps.Experiments.Scenario do
  use SatOps.Schema

  schema "scenarios" do
    field :name, :string
    field :version, :integer
    field :title, :string
    field :description, :string
    field :guarantee, :string
    field :required_capabilities, {:array, :string}, default: []
    field :spec, :map
    field :source_yaml, :string
    timestamps()
  end
end

defmodule SatOps.Experiments.Run do
  use SatOps.Schema

  schema "experiment_runs" do
    field :environment_id, :binary_id
    belongs_to :scenario, SatOps.Experiments.Scenario
    field :scenario_name, :string
    field :scenario_version, :integer
    field :status, :string
    field :seed, :integer
    field :params, :map, default: %{}
    field :status_reason, :string
    field :cleanup_status, :string, default: "pending"
    field :lease_owner, :string
    field :lease_expires_at, :utc_datetime_usec
    field :correlation_id, :binary_id
    field :requested_by, :binary_id
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :report, :map
    field :lock_version, :integer, default: 1
    has_many :steps, SatOps.Experiments.Step
    has_many :assertions, SatOps.Experiments.AssertionResult
    timestamps()
  end
end

defmodule SatOps.Experiments.Step do
  use Ecto.Schema

  schema "experiment_steps" do
    belongs_to :run, SatOps.Experiments.Run, type: :binary_id
    field :position, :integer
    field :step_key, :string
    field :phase, :string
    field :action, :string
    field :params, :map, default: %{}
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 1
    field :timeout_ms, :integer
    field :checkpoint, :map, default: %{}
    field :result, :map
    field :evidence, :map, default: %{}
    field :failure_reason, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
  end
end

defmodule SatOps.Experiments.AssertionResult do
  use Ecto.Schema

  schema "experiment_assertions" do
    belongs_to :run, SatOps.Experiments.Run, type: :binary_id
    field :position, :integer
    field :type, :string
    field :params, :map, default: %{}
    field :outcome, :string
    field :expected, :map
    field :actual, :map
    field :message, :string
    field :attempts, :integer, default: 0
    field :evaluated_at, :utc_datetime_usec
  end
end
