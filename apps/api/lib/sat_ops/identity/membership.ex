defmodule SatOps.Identity.Membership do
  use SatOps.Schema

  schema "memberships" do
    belongs_to :user, SatOps.Identity.User
    field :environment_id, :binary_id
    field :role, :string
    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :environment_id, :role])
    |> validate_required([:user_id, :environment_id, :role])
    |> validate_inclusion(:role, SatOps.Identity.User.roles())
    |> unique_constraint([:user_id, :environment_id])
  end
end
