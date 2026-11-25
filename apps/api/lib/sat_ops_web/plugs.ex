defmodule SatOpsWeb.Plugs.RawBody do
  def init(opts), do: opts
  def call(conn, _opts), do: conn

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        if String.starts_with?(conn.request_path, "/api/webhooks/") do
          {:ok, body, Plug.Conn.assign(conn, :raw_body, (conn.assigns[:raw_body] || "") <> body)}
        else
          {:ok, body, conn}
        end

      other ->
        other
    end
  end
end

defmodule SatOpsWeb.Plugs.SecurityHeaders do
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "same-origin")
    |> put_resp_header("cache-control", "no-store")
  end
end

defmodule SatOpsWeb.Plugs.Auth do
  import Plug.Conn
  alias SatOps.Identity

  @cookie "satops_session"

  def cookie_name, do: @cookie
  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case Identity.fetch_session(conn.cookies[@cookie]) do
      {:ok, session} -> conn |> assign(:current_user, session.user) |> assign(:session, session)
      _ -> conn |> assign(:current_user, nil) |> assign(:session, nil)
    end
  end

  def put_session_cookie(conn, token) do
    put_resp_cookie(conn, @cookie, token,
      http_only: true,
      secure: Application.get_env(:sat_ops, :cookie_secure, false),
      same_site: "Strict",
      max_age: Application.get_env(:sat_ops, :session_ttl_hours, 12) * 3600,
      path: "/"
    )
  end

  def clear_session_cookie(conn), do: delete_resp_cookie(conn, @cookie, path: "/")
end

defmodule SatOpsWeb.Plugs.RequireAuth do
  import Plug.Conn
  def init(opts), do: opts

  def call(%{assigns: %{current_user: nil}} = conn, _opts) do
    conn |> put_resp_content_type("application/json") |> send_resp(401, ~s({"error":"unauthenticated"})) |> halt()
  end

  def call(conn, _opts), do: conn
end

defmodule SatOpsWeb.Plugs.CSRF do
  import Plug.Conn
  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ["GET", "HEAD", "OPTIONS"], do: conn

  def call(%{assigns: %{session: %{csrf_token: expected}}} = conn, _opts) do
    case get_req_header(conn, "x-csrf-token") do
      [token] -> if Plug.Crypto.secure_compare(token, expected), do: conn, else: reject(conn)
      _ -> reject(conn)
    end
  end

  def call(conn, _opts), do: conn

  defp reject(conn) do
    conn |> put_resp_content_type("application/json") |> send_resp(403, ~s({"error":"invalid_csrf_token"})) |> halt()
  end
end

defmodule SatOpsWeb.Plugs.GraphQLContext do
  def init(opts), do: opts

  def call(conn, _opts) do
    Absinthe.Plug.put_options(conn,
      context: %{
        current_user: conn.assigns[:current_user],
        ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
        loader: SatOpsWeb.GraphQL.Loader.new()
      }
    )
  end
end
