defmodule SatOps.Blockchain.Block do
  use Ecto.Schema

  schema "blocks" do
    field :environment_id, :binary_id
    field :hash, :string
    field :height, :integer
    field :prev_hash, :string
    field :chainwork, :decimal
    field :block_time, :utc_datetime_usec
    field :tx_count, :integer
    field :in_best_chain, :boolean
    field :connected_at, :utc_datetime_usec
    field :disconnected_at, :utc_datetime_usec
  end
end

defmodule SatOps.Blockchain.Transaction do
  use Ecto.Schema

  schema "transactions" do
    field :environment_id, :binary_id
    field :txid, :string
    field :status, :string
    field :block_hash, :string
    field :block_height, :integer
    field :fee_sats, :integer
    field :vsize, :integer
    field :is_coinbase, :boolean
    field :replaced_by_txid, :string
    field :conflicts_with, {:array, :string}, default: []
    field :first_seen_at, :utc_datetime_usec
    field :status_changed_at, :utc_datetime_usec
    field :version, :integer
  end
end

defmodule SatOps.Blockchain.Output do
  use Ecto.Schema

  schema "tx_outputs" do
    field :environment_id, :binary_id
    field :txid, :string
    field :vout, :integer
    field :value_sats, :integer
    field :address, :string
    field :script_type, :string
    field :spent_by_txid, :string
    field :spent_by_vin, :integer
  end
end

defmodule SatOps.Blockchain.Input do
  use Ecto.Schema

  schema "tx_inputs" do
    field :environment_id, :binary_id
    field :txid, :string
    field :vin, :integer
    field :prev_txid, :string
    field :prev_vout, :integer
  end
end

defmodule SatOps.Blockchain.StatusChange do
  use Ecto.Schema

  schema "tx_status_changes" do
    field :environment_id, :binary_id
    field :txid, :string
    field :from_status, :string
    field :to_status, :string
    field :block_hash, :string
    field :block_height, :integer
    field :reason, :string
    field :event_id, :binary_id
    field :inserted_at, :utc_datetime_usec
  end
end

defmodule SatOps.Blockchain.NodeObservation do
  use Ecto.Schema

  schema "node_observations" do
    field :environment_id, :binary_id
    field :integration_id, :binary_id
    field :observed_at, :utc_datetime_usec
    field :reachable, :boolean
    field :chain, :string
    field :height, :integer
    field :best_hash, :string
    field :chainwork, :decimal
    field :initial_block_download, :boolean
    field :peers, :integer
    field :mempool_size, :integer
    field :rpc_latency_ms, :integer
    field :error, :string
  end
end
