defmodule SatOps.Ledger.Account do
  use SatOps.Schema

  schema "ledger_accounts" do
    field :environment_id, :binary_id
    field :code, :string
    field :name, :string
    field :type, :string
    field :normal_balance, :string
    field :asset, :string, default: "BTC"
    field :restricted, :boolean, default: false
    field :owner_ref, :string
    timestamps()
  end
end

defmodule SatOps.Ledger.Journal do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}

  schema "ledger_journals" do
    field :environment_id, :binary_id
    field :operation_id, :string
    field :entry_kind, :string
    field :rule_name, :string
    field :rule_version, :integer
    field :description, :string
    field :reverses_journal_id, :binary_id
    field :correlation_id, :binary_id
    field :causation_id, :binary_id
    field :actor_id, :binary_id
    field :metadata, :map, default: %{}
    field :posted_at, :utc_datetime_usec
    has_many :postings, SatOps.Ledger.Posting
  end
end

defmodule SatOps.Ledger.Posting do
  use Ecto.Schema

  schema "ledger_postings" do
    belongs_to :journal, SatOps.Ledger.Journal, type: :binary_id
    field :environment_id, :binary_id
    belongs_to :account, SatOps.Ledger.Account, type: :binary_id
    field :asset, :string
    field :direction, :string
    field :amount_sats, :integer
    field :posted_at, :utc_datetime_usec
  end
end

defmodule SatOps.Ledger.Balance do
  use Ecto.Schema
  @primary_key {:account_id, :binary_id, autogenerate: false}

  schema "ledger_balances" do
    field :environment_id, :binary_id
    field :asset, :string
    field :normal_balance, :string
    field :restricted, :boolean
    field :debit_total, :integer
    field :credit_total, :integer
    field :balance, :integer
    field :version, :integer
    field :updated_at, :utc_datetime_usec
  end
end

defmodule SatOps.Ledger.Operation do
  use SatOps.Schema

  schema "ledger_operations" do
    field :environment_id, :binary_id
    field :operation_id, :string
    field :kind, :string
    field :state, :string
    field :account_ref, :string
    field :counterparty_ref, :string
    field :asset, :string, default: "BTC"
    field :amount_sats, :integer
    field :fee_sats, :integer, default: 0
    field :txid, :string
    field :vout, :integer
    field :block_hash, :string
    field :generation, :integer, default: 0
    field :correlation_id, :binary_id
    field :metadata, :map, default: %{}
    field :lock_version, :integer, default: 1
    timestamps()
  end
end
