defmodule SatOpsWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller

  def error(conn, status, code, message \\ nil) do
    conn |> put_status(status) |> json(%{error: code, message: message}) |> halt()
  end

  def authorize(conn, action, environment_id \\ nil) do
    case SatOps.Identity.authorize(conn.assigns.current_user, action, environment_id) do
      :ok -> :ok
      {:error, :forbidden} -> {:error, error(conn, 403, "forbidden")}
      {:error, :unauthenticated} -> {:error, error(conn, 401, "unauthenticated")}
    end
  end

  def client_ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end
