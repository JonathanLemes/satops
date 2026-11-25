defmodule SatOps.Realtime.Broadcaster do
  @behaviour SatOps.Events.Consumer

  @impl true
  def name, do: "realtime.broadcaster"

  @impl true
  def interested?(_type), do: true

  @impl true
  def handle(event) do
    Phoenix.PubSub.broadcast(
      SatOps.PubSub,
      "realtime:env:#{event.environment_id}",
      {:realtime, event.event_type, %{"eventId" => event.id, "aggregateId" => event.aggregate_id, "seq" => event.seq}}
    )

    :ok
  end
end

defmodule SatOps.Realtime do
  def broadcast(environment_id, topic, payload) do
    Phoenix.PubSub.broadcast(SatOps.PubSub, "realtime:env:#{environment_id}", {:realtime, topic, payload})
  end
end
