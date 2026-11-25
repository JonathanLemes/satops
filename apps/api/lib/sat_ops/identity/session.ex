defmodule SatOps.Identity.Session do
  use SatOps.Schema

  schema "user_sessions" do
    belongs_to :user, SatOps.Identity.User
    field :token_hash, :binary, redact: true
    field :csrf_token, :string, redact: true
    field :expires_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :ip, :string
    field :user_agent, :string
    timestamps(updated_at: false)
  end
end
