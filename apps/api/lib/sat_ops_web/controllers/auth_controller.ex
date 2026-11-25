defmodule SatOpsWeb.AuthController do
  use SatOpsWeb, :controller
  alias SatOps.{Environments, Identity}
  alias SatOpsWeb.Plugs.Auth

  def login(conn, %{"email" => email, "password" => password}) do
    meta = %{ip: client_ip(conn), user_agent: List.first(get_req_header(conn, "user-agent"))}

    case Identity.authenticate(email, password, meta) do
      {:ok, user} ->
        {token, session} = Identity.create_session(user, meta)
        conn |> Auth.put_session_cookie(token) |> json(me_payload(user, session))

      {:error, :rate_limited} ->
        error(conn, 429, "rate_limited", "Too many attempts. Try again in a minute.")

      {:error, _} ->
        error(conn, 401, "invalid_credentials", "Invalid email or password.")
    end
  end

  def login(conn, _), do: error(conn, 400, "bad_request")

  def logout(conn, _params) do
    if session = conn.assigns[:session], do: Identity.delete_session(session)
    conn |> Auth.clear_session_cookie() |> json(%{ok: true})
  end

  def me(conn, _params) do
    case conn.assigns[:current_user] do
      nil -> error(conn, 401, "unauthenticated")
      user -> json(conn, me_payload(user, conn.assigns.session))
    end
  end

  def password(conn, %{"current" => current, "new" => new}) do
    case Identity.change_password(conn.assigns.current_user, current, new) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, :invalid_credentials} -> error(conn, 400, "invalid_credentials", "Current password is incorrect.")
      {:error, %Ecto.Changeset{}} -> error(conn, 422, "invalid_password", "Password must have at least 12 characters.")
    end
  end

  def me_payload(user, session) do
    envs = Environments.list(Identity.environment_ids_for(user))

    %{
      user: %{id: user.id, email: user.email, name: user.name, role: user.role, locale: user.locale},
      csrfToken: session.csrf_token,
      socketToken: Identity.socket_token(session),
      permissions: Identity.permissions(user),
      environments:
        Enum.map(envs, fn e ->
          %{
            id: e.id,
            slug: e.slug,
            name: e.name,
            role: Identity.role_in(user, e.id),
            permissions: Identity.permissions(user, e.id)
          }
        end)
    }
  end
end
