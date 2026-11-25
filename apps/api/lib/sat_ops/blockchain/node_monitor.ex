defmodule SatOps.Blockchain.NodeMonitor do
  use GenServer, restart: :transient
  require Logger
  alias SatOps.{Integrations, Repo}
  alias SatOps.Blockchain.{NodeObservation, Workers}
  alias SatOps.Infrastructure.Bitcoin.ZMQ

  def start_link(integration) do
    GenServer.start_link(__MODULE__, integration, name: {:via, Registry, {SatOps.Registry, {:node, integration.id}}})
  end

  def check_now(integration_id) do
    case Registry.lookup(SatOps.Registry, {:node, integration_id}) do
      [{pid, _}] -> send(pid, :check)
      [] -> :not_running
    end
  end

  @impl true
  def init(integration) do
    Process.flag(:trap_exit, true)
    Logger.metadata(integration_id: integration.id, environment_id: integration.environment_id)

    state = %{
      integration: integration,
      interval: integration.config["reconcileIntervalMs"] || 30_000,
      failures: 0,
      last_tip: nil,
      zmq: nil,
      zmq_attempts: 0,
      zmq_seq: %{},
      gaps: 0,
      duplicates: 0
    }

    send(self(), :check)
    send(self(), :start_zmq)
    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    result = Integrations.test_connection(state.integration)
    record_observation(state.integration, result)

    state =
      case result do
        {:ok, %{"bestHash" => tip}} ->
          if tip != state.last_tip, do: Workers.SyncChain.enqueue(state.integration.environment_id, "tip_changed")
          %{state | failures: 0, last_tip: tip}

        {:error, reason} ->
          Logger.warning("bitcoin node check failed: #{Integrations.format_error(reason)}")
          %{state | failures: state.failures + 1}
      end

    Process.send_after(self(), :check, next_delay(state))
    {:noreply, state}
  end

  def handle_info(:start_zmq, %{integration: %{config: %{"zmqEnabled" => true, "zmqEndpoint" => endpoint}}} = state)
      when is_binary(endpoint) do
    parent = self()
    pid = spawn_link(fn -> zmq_loop(parent, endpoint) end)
    {:noreply, %{state | zmq: pid}}
  end

  def handle_info(:start_zmq, state), do: {:noreply, state}

  def handle_info({:zmq, frames}, state) do
    case ZMQ.parse_sequence_message(frames) do
      {:ok, msg} -> {:noreply, handle_zmq(msg, state)}
      {:error, _} -> {:noreply, state}
    end
  end

  def handle_info({:EXIT, pid, reason}, %{zmq: pid} = state) do
    attempts = state.zmq_attempts + 1
    delay = SatOps.Backoff.delay(attempts, base_ms: 1_000, max_ms: 60_000)
    Logger.warning("zmq subscriber stopped (#{inspect(reason)}), reconnecting in #{delay}ms")
    :telemetry.execute([:sat_ops, :integration, :reconnect], %{count: 1}, %{kind: "zmq"})
    Process.send_after(self(), :start_zmq, delay)
    {:noreply, %{state | zmq: nil, zmq_attempts: attempts}}
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}

  defp handle_zmq(msg, state) do
    last = Map.get(state.zmq_seq, msg.topic)
    state = %{state | zmq_attempts: 0}

    case ZMQ.track_sequence(last, msg.zmq_seq) do
      {:ok, seq} ->
        if msg.kind in [:block_connected, :block_disconnected, :tx_added, :tx_removed, :hashblock] do
          Workers.SyncChain.enqueue(state.integration.environment_id, "zmq_#{msg.kind}")
        end

        %{state | zmq_seq: Map.put(state.zmq_seq, msg.topic, seq)}

      {:duplicate, _} ->
        persist_zmq(state, 0, 1)
        %{state | duplicates: state.duplicates + 1}

      {:gap, seq, size} ->
        Logger.warning("zmq sequence gap of #{size} on #{msg.topic}; scheduling RPC backfill")
        :telemetry.execute([:sat_ops, :zmq, :gap], %{count: 1, size: size}, %{})
        persist_zmq(state, 1, 0, seq)
        Workers.SyncChain.enqueue(state.integration.environment_id, "zmq_gap")
        %{state | zmq_seq: Map.put(state.zmq_seq, msg.topic, seq), gaps: state.gaps + 1}
    end
  end

  defp persist_zmq(state, gaps, dups, seq \\ nil) do
    Repo.query(
      """
      INSERT INTO zmq_checkpoints (integration_id, last_sequence, gaps_total, duplicates_total, updated_at)
      VALUES ($1, $2, $3, $4, now())
      ON CONFLICT (integration_id) DO UPDATE SET
        last_sequence = COALESCE($2, zmq_checkpoints.last_sequence),
        gaps_total = zmq_checkpoints.gaps_total + $3,
        duplicates_total = zmq_checkpoints.duplicates_total + $4,
        updated_at = now()
      """,
      [Ecto.UUID.dump!(state.integration.id), seq, gaps, dups]
    )
  end

  defp zmq_loop(parent, endpoint) do
    %URI{host: host, port: port} = URI.parse(endpoint)
    {:ok, socket} = :chumak.socket(:sub)
    :ok = :chumak.subscribe(socket, "sequence")
    {:ok, _peer} = :chumak.connect(socket, :tcp, String.to_charlist(host), port)
    recv(parent, socket)
  end

  defp recv(parent, socket) do
    case :chumak.recv_multipart(socket) do
      {:ok, frames} ->
        send(parent, {:zmq, frames})
        recv(parent, socket)

      {:error, reason} ->
        exit({:zmq_recv_failed, reason})
    end
  end

  defp next_delay(%{failures: 0, interval: interval}), do: interval

  defp next_delay(%{failures: n, interval: interval}),
    do: min(SatOps.Backoff.delay(n, base_ms: 2_000, max_ms: 60_000), max(interval, 60_000))

  defp record_observation(integration, result) do
    now = DateTime.utc_now()

    obs =
      case result do
        {:ok, h} ->
          %NodeObservation{
            reachable: true,
            chain: h["chain"],
            height: h["height"],
            best_hash: h["bestHash"],
            chainwork: h["chainwork"] && Decimal.new(String.to_integer(h["chainwork"], 16)),
            initial_block_download: h["initialBlockDownload"],
            peers: h["peers"],
            mempool_size: h["mempoolSize"],
            rpc_latency_ms: h["latencyMs"]
          }

        {:error, reason} ->
          %NodeObservation{reachable: false, error: Integrations.format_error(reason)}
      end

    Repo.insert!(%{obs | environment_id: integration.environment_id, integration_id: integration.id, observed_at: now})

    Phoenix.PubSub.broadcast(
      SatOps.PubSub,
      "realtime:env:#{integration.environment_id}",
      {:realtime, "node.status", %{"integrationId" => integration.id}}
    )
  end
end
