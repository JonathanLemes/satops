defmodule SatOps.Environments.Environment do
  use SatOps.Schema

  schema "environments" do
    field :slug, :string
    field :name, :string
    field :kind, :string, default: "persistent"
    field :network, :string, default: "regtest"
    field :status, :string, default: "active"
    field :required_confirmations, :integer, default: 3
    field :settings, :map, default: %{}
    field :expires_at, :utc_datetime_usec
    timestamps()
  end

  def changeset(env, attrs) do
    env
    |> cast(attrs, [:slug, :name, :kind, :network, :status, :required_confirmations, :settings, :expires_at])
    |> validate_required([:slug, :name])
    |> validate_format(:slug, ~r/^[a-z0-9]([a-z0-9-]{0,48}[a-z0-9])?$/)
    |> validate_inclusion(:kind, ["persistent", "ephemeral"])
    |> validate_inclusion(:network, ["regtest"], message: "only regtest networks are allowed in SatOps sandboxes")
    |> validate_inclusion(:status, ["active", "archived"])
    |> validate_number(:required_confirmations, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
    |> validate_safety()
    |> unique_constraint(:slug)
    |> check_constraint(:network, name: :environments_network_regtest)
  end

  defp validate_safety(changeset) do
    safety = get_field(changeset, :settings) |> Map.get("safety", %{})

    cond do
      safety["allowMainnet"] == true -> add_error(changeset, :settings, "safety.allowMainnet cannot be enabled")
      safety["allowPublicPeers"] == true -> add_error(changeset, :settings, "safety.allowPublicPeers cannot be enabled")
      true -> changeset
    end
  end
end
