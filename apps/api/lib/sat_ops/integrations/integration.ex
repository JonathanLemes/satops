defmodule SatOps.Integrations.Integration do
  use SatOps.Schema

  @kinds ~w(bitcoin_core demo_fintech generic_rest csv_import webhook_receiver webhook_destination kubernetes)

  schema "integrations" do
    field :environment_id, :binary_id
    field :name, :string
    field :kind, :string
    field :config, :map, default: %{}
    field :secret_ref, :string
    field :enabled, :boolean, default: true
    field :status, :string, default: "unknown"
    field :health, :map, default: %{}
    field :capabilities, {:array, :string}, default: []
    field :enabled_operations, {:array, :string}, default: []
    field :retry, :map, default: %{}
    field :checkpoint, :map, default: %{}
    field :last_sync_at, :utc_datetime_usec
    field :last_error, :string
    field :lock_version, :integer, default: 1
    timestamps()
  end

  def kinds, do: @kinds

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:environment_id, :name, :kind, :config, :secret_ref, :enabled, :retry, :enabled_operations])
    |> validate_required([:environment_id, :name, :kind])
    |> validate_inclusion(:kind, @kinds)
    |> validate_format(:name, ~r/^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$/)
    |> validate_format(:secret_ref, ~r/^[a-z0-9][a-z0-9-_.]{0,62}$/)
    |> validate_config()
    |> optimistic_lock(:lock_version)
    |> unique_constraint([:environment_id, :name])
  end

  defp validate_config(changeset) do
    kind = get_field(changeset, :kind)
    config = get_field(changeset, :config) || %{}

    case SatOps.Integrations.adapter(kind) do
      nil ->
        changeset

      adapter ->
        case adapter.validate_configuration(config) do
          {:ok, normalized} ->
            changeset
            |> put_change(:config, normalized)
            |> put_change(:capabilities, adapter.capabilities())

          {:error, errors} when is_list(errors) ->
            Enum.reduce(errors, changeset, fn e, cs -> add_error(cs, :config, e) end)

          {:error, error} ->
            add_error(changeset, :config, to_string(error))
        end
    end
  end
end
