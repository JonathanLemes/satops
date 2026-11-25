defmodule SatOps.Events do
  import Ecto.Query
  alias SatOps.Repo
  alias SatOps.Events.{DispatchWorker, Event}

  @lock_key 7_301_042_001

  def consumers do
    [SatOps.Ledger.ChainConsumer, SatOps.Alerts.EventConsumer, SatOps.Realtime.Broadcaster]
  end

  def append!(attrs) do
    unless Repo.in_transaction?(), do: raise(ArgumentError, "Events.append!/1 must run inside a transaction")
    Repo.query!("SELECT pg_advisory_xact_lock($1)", [@lock_key])
    now = DateTime.utc_now()
    type = fetch!(attrs, :event_type)
    unless type in Event.types(), do: raise(ArgumentError, "unknown event type #{type}")

    event = %Event{
      id: attrs[:id] || Ecto.UUID.generate(),
      event_type: type,
      schema_version: attrs[:schema_version] || 1,
      environment_id: fetch!(attrs, :environment_id),
      network_id: attrs[:network_id],
      aggregate_type: fetch!(attrs, :aggregate_type),
      aggregate_id: to_string(fetch!(attrs, :aggregate_id)),
      aggregate_version: attrs[:aggregate_version],
      occurred_at: attrs[:occurred_at] || now,
      observed_at: now,
      correlation_id: attrs[:correlation_id] || Ecto.UUID.generate(),
      causation_id: attrs[:causation_id],
      dedupe_key: attrs[:dedupe_key],
      payload: attrs[:payload] || %{}
    }

    case Repo.insert(event, on_conflict: :nothing, conflict_target: [:environment_id, :dedupe_key], returning: true) do
      {:ok, %Event{seq: nil}} ->
        {:duplicate, Repo.get_by!(Event, environment_id: event.environment_id, dedupe_key: event.dedupe_key)}

      {:ok, inserted} ->
        schedule_dispatch(type)
        {:ok, inserted}
    end
  end

  defp fetch!(attrs, key), do: Map.get(attrs, key) || raise(ArgumentError, "missing #{key}")

  defp schedule_dispatch(type) do
    for consumer <- consumers(), consumer.interested?(type) do
      %{consumer: consumer.name()} |> DispatchWorker.new() |> Oban.insert!()
    end
  end

  def list(environment_id, opts \\ []) do
    Event
    |> where([e], e.environment_id == ^environment_id)
    |> maybe(opts[:types], fn q, t -> where(q, [e], e.event_type in ^t) end)
    |> maybe(opts[:aggregate_id], fn q, a -> where(q, [e], e.aggregate_id == ^a) end)
    |> maybe(opts[:correlation_id], fn q, c -> where(q, [e], e.correlation_id == ^c) end)
    |> maybe(opts[:before_seq], fn q, s -> where(q, [e], e.seq < ^s) end)
    |> order_by(desc: :seq)
    |> limit(^min(opts[:limit] || 50, 500))
    |> Repo.all()
  end

  def get(id), do: Repo.get(Event, id)

  def related(environment_id, correlation_ids) do
    Repo.all(
      from e in Event,
        where: e.environment_id == ^environment_id and e.correlation_id in ^correlation_ids,
        order_by: e.seq
    )
  end

  defp maybe(q, nil, _), do: q
  defp maybe(q, [], _), do: q
  defp maybe(q, v, f), do: f.(q, v)

  def checkpoints do
    Repo.all(
      from c in "consumer_checkpoints", select: %{consumer: c.consumer, last_seq: c.last_seq, updated_at: c.updated_at}
    )
  end

  def head_seq, do: Repo.one(from e in Event, select: max(e.seq)) || 0

  def replay(consumer_name, from_seq) when is_integer(from_seq) and from_seq >= 0 do
    consumer = Enum.find(consumers(), &(&1.name() == consumer_name)) || raise ArgumentError, "unknown consumer"

    Repo.transaction(fn ->
      Repo.query!(
        "INSERT INTO consumer_checkpoints (consumer, last_seq) VALUES ($1, $2) ON CONFLICT (consumer) DO UPDATE SET last_seq = LEAST(consumer_checkpoints.last_seq, EXCLUDED.last_seq), updated_at = now()",
        [consumer_name, max(from_seq - 1, 0)]
      )

      Repo.query!(
        "DELETE FROM processed_events p USING events e WHERE p.consumer = $1 AND p.event_id = e.id AND e.seq >= $2",
        [consumer_name, from_seq]
      )

      %{consumer: consumer.name()} |> DispatchWorker.new() |> Oban.insert!()
    end)
  end
end
