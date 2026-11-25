defmodule SatOps.Identity.User do
  use SatOps.Schema

  @roles ~w(administrator engineer auditor viewer)

  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :role, :string
    field :locale, :string, default: "en"
    field :disabled_at, :utc_datetime_usec
    timestamps()
  end

  def roles, do: @roles

  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password, :role, :locale])
    |> validate_required([:email, :name, :password, :role])
    |> common_validations()
    |> validate_password()
    |> hash_password()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :role, :locale, :disabled_at])
    |> common_validations()
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password()
  end

  defp common_validations(changeset) do
    changeset
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+$/)
    |> validate_length(:email, max: 160)
    |> validate_length(:name, min: 1, max: 120)
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:locale, ["en", "pt-BR"])
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 12, max: 256)
  end

  defp hash_password(%{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  defp hash_password(changeset), do: changeset
end
