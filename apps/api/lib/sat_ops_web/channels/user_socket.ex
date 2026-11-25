defmodule SatOpsWeb.UserSocket do
  use Phoenix.Socket

  channel "env:*", SatOpsWeb.EnvironmentChannel

  @impl true
  def connect(_params, socket, connect_info) do
    token =
      case Map.get(connect_info, :cookies) do
        cookies when is_map(cookies) ->
          Map.get(cookies, "satops_session")

        cookies when is_list(cookies) ->
          Enum.find_value(cookies, fn {k, v} -> if to_string(k) == "satops_session", do: v end)

        _ ->
          nil
      end

    case SatOps.Identity.fetch_session(token) do
      {:ok, session} -> {:ok, assign(socket, :user, session.user)}
      _ -> :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user.id}"
end

defmodule SatOpsWeb.EnvironmentChannel do
  use SatOpsWeb, :channel

  @impl true
  def join("env:" <> environment_id, _payload, socket) do
    if SatOps.Identity.can?(socket.assigns.user, :"environment.read", environment_id) do
      Phoenix.PubSub.subscribe(SatOps.PubSub, "realtime:env:#{environment_id}")
      {:ok, assign(socket, :environment_id, environment_id)}
    else
      {:error, %{reason: "forbidden"}}
    end
  end

  @impl true
  def handle_info({:realtime, topic, payload}, socket) do
    push(socket, "event", %{topic: topic, payload: payload})
    {:noreply, socket}
  end
end
