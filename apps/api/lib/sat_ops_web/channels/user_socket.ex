defmodule SatOpsWeb.UserSocket do
  use Phoenix.Socket

  channel "env:*", SatOpsWeb.EnvironmentChannel

  @impl true
  def connect(params, socket, _connect_info) do
    case SatOps.Identity.fetch_socket_session(params["token"]) do
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
