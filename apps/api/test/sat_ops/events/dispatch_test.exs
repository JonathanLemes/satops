defmodule SatOps.Events.DispatchTest do
  use SatOps.DataCase
  alias SatOps.Events
  alias SatOps.Events.DispatchWorker

  defmodule Counter do
    @behaviour SatOps.Events.Consumer
    def name, do: "test.counter"
    def interested?(t), do: t == "node.synchronized"

    def handle(event) do
      SatOps.Repo.insert_all("integration_errors", [], [])
      send(Process.whereis(:dispatch_test), {:handled, event.id})
      :ok
    end
  end

  setup do
    Process.register(self(), :dispatch_test)
    {:ok, env: environment()}
  end

  test "events are appended in commit order with dedupe keys", %{env: env} do
    {:ok, {:ok, e1}} =
      Repo.transaction(fn ->
        Events.append!(%{
          event_type: "node.synchronized",
          environment_id: env.id,
          aggregate_type: "chain",
          aggregate_id: "x",
          dedupe_key: "k1"
        })
      end)

    {:ok, {:duplicate, e2}} =
      Repo.transaction(fn ->
        Events.append!(%{
          event_type: "node.synchronized",
          environment_id: env.id,
          aggregate_type: "chain",
          aggregate_id: "x",
          dedupe_key: "k1"
        })
      end)

    assert e1.id == e2.id

    assert_raise ArgumentError, fn ->
      Events.append!(%{event_type: "x", environment_id: env.id, aggregate_type: "a", aggregate_id: "b"})
    end
  end

  test "a consumer processes each event once even when the dispatcher runs repeatedly", %{env: env} do
    {:ok, {:ok, event}} =
      Repo.transaction(fn ->
        Events.append!(%{
          event_type: "node.synchronized",
          environment_id: env.id,
          aggregate_type: "chain",
          aggregate_id: "y"
        })
      end)

    Repo.query!(
      "INSERT INTO consumer_checkpoints (consumer, last_seq) VALUES ($1, $2) ON CONFLICT (consumer) DO UPDATE SET last_seq = $2",
      ["test.counter", event.seq - 1]
    )

    assert :ok = DispatchWorker.drain(Counter, 10)
    assert_received {:handled, id} when id == event.id

    Repo.query!("UPDATE consumer_checkpoints SET last_seq = $2 WHERE consumer = $1", ["test.counter", event.seq - 1])
    assert :ok = DispatchWorker.drain(Counter, 10)
    refute_received {:handled, _}
  end

  test "events are immutable", %{env: env} do
    {:ok, {:ok, e}} =
      Repo.transaction(fn ->
        Events.append!(%{
          event_type: "node.synchronized",
          environment_id: env.id,
          aggregate_type: "c",
          aggregate_id: "z"
        })
      end)

    assert_raise Postgrex.Error, fn -> Repo.query!("DELETE FROM events WHERE id = $1", [Ecto.UUID.dump!(e.id)]) end
  end
end
