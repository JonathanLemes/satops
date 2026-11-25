defmodule SatOps.Events.Event do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "events" do
    field :seq, :integer, read_after_writes: true
    field :event_type, :string
    field :schema_version, :integer, default: 1
    field :environment_id, :binary_id
    field :network_id, :string
    field :aggregate_type, :string
    field :aggregate_id, :string
    field :aggregate_version, :integer
    field :occurred_at, :utc_datetime_usec
    field :observed_at, :utc_datetime_usec
    field :correlation_id, :binary_id
    field :causation_id, :binary_id
    field :dedupe_key, :string
    field :payload, :map, default: %{}
  end

  @types ~w(
    block.connected block.disconnected chain.reorganized
    transaction.observed transaction.confirmed transaction.unconfirmed transaction.replaced transaction.conflicted
    node.disconnected node.reconnected node.synchronized node.diverged
    ledger.journal_posted ledger.deposit_credited ledger.deposit_reversed ledger.invariant_violated
    reconciliation.completed reconciliation.discrepancy_detected reconciliation.incomplete
    experiment.started experiment.step_completed experiment.finished
    integration.unavailable integration.recovered integration.records_received
    config.applied alert.fired
  )

  def types, do: @types
end
