defmodule SatOps.Identity do
  import Ecto.Query
  alias SatOps.{Audit, Repo}
  alias SatOps.Identity.{Membership, Policy, RateLimiter, Session, User}

  @dummy_hash Argon2.hash_pwd_salt("timing-equalizer")

  def get_user(id), do: Repo.get(User, id)

  def list_users, do: Repo.all(from u in User, order_by: u.email)

  def count_users, do: Repo.aggregate(User, :count)

  def create_user(attrs, actor \\ nil) do
    Repo.transaction(fn ->
      with {:ok, user} <- %User{} |> User.create_changeset(attrs) |> Repo.insert() do
        Audit.record!(actor, "user.created", resource: user, changes: %{email: user.email, role: user.role})
        user
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_user(%User{} = user, attrs, actor) do
    Repo.transaction(fn ->
      with {:ok, updated} <- user |> User.update_changeset(attrs) |> Repo.update() do
        if updated.disabled_at, do: Repo.delete_all(from s in Session, where: s.user_id == ^updated.id)

        Audit.record!(actor, "user.updated",
          resource: updated,
          changes: Map.take(attrs, ["name", "role", "locale", "disabled_at", :name, :role, :locale])
        )

        updated
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def authenticate(email, password, meta \\ %{}) do
    {limit, window} = Application.get_env(:sat_ops, :login_rate_limit, {10, 60_000})
    bucket = {:login, String.downcase(to_string(email)), meta[:ip]}

    with :ok <- RateLimiter.hit(bucket, limit, window) do
      user = Repo.get_by(User, email: String.downcase(String.trim(to_string(email))))

      cond do
        user && is_nil(user.disabled_at) && Argon2.verify_pass(to_string(password), user.password_hash) ->
          Audit.record!(user, "auth.login", resource: user, ip: meta[:ip])
          {:ok, user}

        user ->
          Audit.record!(nil, "auth.login_failed", resource: user, ip: meta[:ip])
          {:error, :invalid_credentials}

        true ->
          Argon2.verify_pass("x", @dummy_hash)
          {:error, :invalid_credentials}
      end
    end
  end

  def create_session(%User{} = user, meta \\ %{}) do
    token = :crypto.strong_rand_bytes(32)
    csrf = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    now = DateTime.utc_now()
    ttl = Application.get_env(:sat_ops, :session_ttl_hours, 12)

    session =
      Repo.insert!(%Session{
        user_id: user.id,
        token_hash: hash(token),
        csrf_token: csrf,
        expires_at: DateTime.add(now, ttl * 3600, :second),
        last_seen_at: now,
        ip: meta[:ip],
        user_agent: meta[:user_agent] |> to_string() |> String.slice(0, 300)
      })

    {Base.url_encode64(token, padding: false), session}
  end

  def fetch_session(encoded) when is_binary(encoded) do
    with {:ok, token} <- Base.url_decode64(encoded, padding: false),
         %Session{} = session <-
           Repo.one(
             from s in Session,
               where: s.token_hash == ^hash(token) and s.expires_at > ^DateTime.utc_now(),
               preload: :user
           ),
         nil <- session.user.disabled_at do
      maybe_touch(session)
      {:ok, session}
    else
      _ -> {:error, :invalid_session}
    end
  end

  def fetch_session(_), do: {:error, :invalid_session}

  def delete_session(%Session{id: id}), do: Repo.delete_all(from s in Session, where: s.id == ^id)

  def purge_expired_sessions do
    Repo.delete_all(from s in Session, where: s.expires_at < ^DateTime.utc_now())
  end

  defp maybe_touch(session) do
    if DateTime.diff(DateTime.utc_now(), session.last_seen_at) > 60 do
      Repo.update_all(from(s in Session, where: s.id == ^session.id), set: [last_seen_at: DateTime.utc_now()])
    end
  end

  defp hash(token), do: :crypto.hash(:sha256, token)

  def change_password(%User{} = user, current, new) do
    if Argon2.verify_pass(current, user.password_hash) do
      Repo.transaction(fn ->
        updated = user |> User.password_changeset(%{password: new}) |> Repo.update()

        case updated do
          {:ok, u} ->
            Audit.record!(u, "user.password_changed", resource: u)
            u

          {:error, cs} ->
            Repo.rollback(cs)
        end
      end)
    else
      {:error, :invalid_credentials}
    end
  end

  def membership(user_id, environment_id) do
    Repo.get_by(Membership, user_id: user_id, environment_id: environment_id)
  end

  def put_membership(user_id, environment_id, role, actor) do
    Repo.transaction(fn ->
      result =
        %Membership{}
        |> Membership.changeset(%{user_id: user_id, environment_id: environment_id, role: role})
        |> Repo.insert(
          on_conflict: [set: [role: role, updated_at: DateTime.utc_now()]],
          conflict_target: [:user_id, :environment_id]
        )

      case result do
        {:ok, m} ->
          Audit.record!(actor, "membership.updated",
            environment_id: environment_id,
            resource_type: "user",
            resource_id: user_id,
            changes: %{role: role}
          )

          m

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  def environment_ids_for(%User{role: "administrator"}), do: :all

  def environment_ids_for(%User{id: id}) do
    Repo.all(from m in Membership, where: m.user_id == ^id, select: m.environment_id)
  end

  def role_in(%User{} = user, nil), do: user.role
  def role_in(%User{} = user, environment_id), do: Policy.effective_role(user, membership(user.id, environment_id))

  def authorize(user, action, environment_id \\ nil)
  def authorize(nil, _action, _env), do: {:error, :unauthenticated}

  def authorize(%User{} = user, action, environment_id) do
    if Policy.allowed?(role_in(user, environment_id), action), do: :ok, else: {:error, :forbidden}
  end

  def can?(user, action, environment_id \\ nil), do: authorize(user, action, environment_id) == :ok

  def permissions(%User{} = user, environment_id \\ nil), do: Policy.permissions(role_in(user, environment_id) || "")
end
