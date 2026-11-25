defmodule SatOps.Events.DispatchWorker do
  use Oban.Worker,
    queue: :events,
    max_attempts: 20,
    unique: [keys: [:consumer], states: [:available, :scheduled, :retryable], period: :infinity]

  require Logger
  alias SatOps.Repo
  alias SatOps.Events.Event

  @batch 200

  @impl true
  def perform(%Oban.Job{args: %{"consumer" => name}}) do
    consumer = Enum.find(SatOps.Events.consumers(), &(&1.name() == name))
    if consumer, do: drain(consumer, @batch), else: {:cancel, :unknown_consumer}
  end

  @impl true
  def backoff(%Oban.Job{attempt: attempt}),
    do: div(SatOps.Backoff.delay(attempt, base_ms: 1_000, max_ms: 120_000), 1000)

  def drain(consumer, 0) do
    %{consumer: consumer.name()} |> new(schedule_in: 1) |> Oban.insert!()
    :ok
  end

  def drain(consumer, budget) do
    case step(consumer) do
      :idle -> :ok
      :processed -> drain(consumer, budget - 1)
      {:error, reason} -> {:error, reason}
    end
  end

  def step(consumer) do
    name = consumer.name()

    Repo.transaction(fn ->
      Repo.query!("INSERT INTO consumer_checkpoints (consumer, last_seq) VALUES ($1, 0) ON CONFLICT DO NOTHING", [name])

      %{rows: [[last_seq]]} =
        Repo.query!("SELECT last_seq FROM consumer_checkpoints WHERE consumer = $1 FOR UPDATE", [name])

      import Ecto.Query
      event = Repo.one(from e in Event, where: e.seq > ^last_seq, order_by: e.seq, limit: 1)

      cond do
        is_nil(event) ->
          :idle

        not consumer.interested?(event.event_type) ->
          advance(name, event.seq)
          :processed

        true ->
          %{num_rows: inserted} =
            Repo.query!("INSERT INTO processed_events (consumer, event_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", [
              name,
              Ecto.UUID.dump!(event.id)
            ])

          if inserted == 1 do
            Logger.metadata(
              event_id: event.id,
              correlation_id: event.correlation_id,
              environment_id: event.environment_id
            )

            case consumer.handle(event) do
              :ok -> :ok
              {:error, reason} -> Repo.rollback({:handler_failed, event.seq, reason})
            end
          end

          advance(name, event.seq)
          :processed
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp advance(name, seq) do
    Repo.query!("UPDATE consumer_checkpoints SET last_seq = $2, updated_at = now() WHERE consumer = $1", [name, seq])
  end
end
