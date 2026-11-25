defmodule SatOps.Experiments.Actions.Integration.Helpers do
  alias SatOps.Experiments.Context
  alias SatOps.Integrations.Adapters.DemoFintech

  def call(ctx, p, method, path, body \\ nil) do
    with {:ok, integration, token} <- Context.fintech(ctx, p["integration"]) do
      case DemoFintech.call(integration, token, method, path, body) do
        {:ok, %{body: body}} -> {:ok, body}
        {:error, reason} -> {:error, SatOps.Integrations.format_error(reason)}
      end
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.CreateCustomer do
  use SatOps.Experiments.Actions.Base,
    name: "integration.create_customer",
    idempotency: :keyed,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def validate(p), do: str(p, "as")

  @impl true
  def run(p, ctx) do
    external = "#{p["as"]}-#{String.slice(ctx.run.id, 0, 8)}"

    with {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/customers", %{externalRef: external, name: p["name"] || p["as"]}) do
      {:ok, %{"customerId" => body["id"], "refs" => %{p["as"] => body["id"]}}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.RequestDepositAddress do
  use SatOps.Experiments.Actions.Base,
    name: "integration.request_deposit_address",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def validate(p) do
    with :ok <- str(p, "customerRef"), do: str(p, "as")
  end

  @impl true
  def run(p, ctx) do
    with {:ok, customer} <- Context.ref(ctx, p["customerRef"]),
         {:ok, body} <- Helpers.call(ctx, p, :post, "/v1/customers/#{customer}/deposit-addresses"),
         :ok <- SatOps.Integrations.Sync.sync_environment(ctx.env.id) do
      {:ok, %{"address" => body["address"], "refs" => %{p["as"] => body["address"]}}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.RequestWithdrawal do
  use SatOps.Experiments.Actions.Base,
    name: "integration.request_withdrawal",
    idempotency: :keyed,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def validate(p) do
    with :ok <- str(p, "customerRef"), :ok <- str(p, "toRef"), do: int(p, "amountSats", 546, 2_100_000_000_000_000)
  end

  @impl true
  def run(p, ctx) do
    with {:ok, customer} <- Context.ref(ctx, p["customerRef"]),
         {:ok, to} <- Context.ref(ctx, p["toRef"]),
         {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/withdrawals", %{
             customerId: customer,
             amountSats: p["amountSats"],
             address: to,
             idempotencyKey: "#{ctx.run.id}:#{p["as"] || "withdrawal"}"
           }) do
      refs = if p["as"], do: %{p["as"] => body["txid"] || body["id"]}, else: %{}
      {:ok, %{"withdrawal" => body, "refs" => refs}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.SetFault do
  use SatOps.Experiments.Actions.Base,
    name: "integration.set_fault",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @modes ~w(duplicate_deposit_credit missing_deposit_credit incorrect_amount delayed_settlement ignore_reorg duplicate_webhook_processing invalid_balance_projection temporary_api_outage timeout_after_success delay_response)

  @impl true
  def validate(p) do
    if p["mode"] in @modes and is_boolean(p["enabled"]),
      do: :ok,
      else: {:error, "mode must be one of #{Enum.join(@modes, ", ")} and enabled a boolean"}
  end

  @impl true
  def run(p, ctx) do
    with {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/faults", %{mode: p["mode"], enabled: p["enabled"], delayMs: p["delayMs"]}) do
      {:ok, %{"faults" => body["faults"]}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.DeliverEvent do
  use SatOps.Experiments.Actions.Base,
    name: "integration.deliver_event",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def run(p, ctx) do
    with {:ok, body} <- Helpers.call(ctx, p, :post, "/v1/test/webhooks/flush", %{}) do
      {:ok, %{"delivered" => body["delivered"]}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.RedeliverEvent do
  use SatOps.Experiments.Actions.Base,
    name: "integration.redeliver_event",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def validate(p), do: int(p, "times", 1, 100)

  @impl true
  def run(p, ctx) do
    with {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/test/webhooks/redeliver", %{times: p["times"], last: p["last"] || 10}) do
      {:ok, %{"attempts" => body["attempts"], "accepted" => body["accepted"], "duplicates" => body["duplicates"]}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.ReorderEvents do
  use SatOps.Experiments.Actions.Base,
    name: "integration.reorder_events",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def run(p, ctx) do
    with {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/test/webhooks/redeliver", %{
             times: 1,
             last: p["last"] || 10,
             order: "reverse"
           }) do
      {:ok, %{"attempts" => body["attempts"]}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.DelayResponse do
  use SatOps.Experiments.Actions.Base,
    name: "integration.delay_response",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def validate(p), do: int(p, "delayMs", 0, 30_000)

  @impl true
  def run(p, ctx) do
    with {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/faults", %{
             mode: "delay_response",
             enabled: p["delayMs"] > 0,
             delayMs: p["delayMs"]
           }) do
      {:ok, %{"faults" => body["faults"]}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.SimulateTimeout do
  use SatOps.Experiments.Actions.Base,
    name: "integration.simulate_timeout",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  alias SatOps.Experiments.Actions.Integration.Helpers

  @impl true
  def run(p, ctx) do
    with {:ok, body} <-
           Helpers.call(ctx, p, :post, "/v1/faults", %{
             mode: "timeout_after_success",
             enabled: Map.get(p, "enabled", true)
           }) do
      {:ok, %{"faults" => body["faults"]}}
    end
  end
end

defmodule SatOps.Experiments.Actions.Integration.Sync do
  use SatOps.Experiments.Actions.Base,
    name: "integration.sync",
    idempotency: :natural,
    capabilities: ["integration.demo_fintech"]

  @impl true
  def run(_p, ctx) do
    SatOps.Integrations.Sync.sync_environment(ctx.env.id)
    {:ok, %{"synced" => true}}
  end
end

defmodule SatOps.Experiments.Actions.Ledger.RequestWithdrawal do
  use SatOps.Experiments.Actions.Base, name: "ledger.request_withdrawal", idempotency: :keyed, capabilities: ["ledger"]

  @impl true
  def validate(p) do
    with :ok <- str(p, "accountRef"), :ok <- str(p, "key"), do: int(p, "amountSats", 1, 2_100_000_000_000_000)
  end

  @impl true
  def run(p, ctx) do
    with {:ok, ref} <- Context.resolve(ctx, p["accountRef"]) do
      case SatOps.Ledger.request_withdrawal(
             ctx.env.id,
             ref,
             p["amountSats"],
             p["feeSats"] || 0,
             "#{ctx.run.id}:#{p["key"]}",
             nil
           ) do
        {:ok, journal, status} -> {:ok, %{"journalId" => journal.id, "status" => to_string(status)}}
        {:error, reason} -> {:error, inspect(reason)}
      end
    end
  end
end

defmodule SatOps.Experiments.Actions.Ledger.ConcurrentWithdrawals do
  use SatOps.Experiments.Actions.Base,
    name: "ledger.concurrent_withdrawals",
    idempotency: :keyed,
    capabilities: ["ledger"]

  @impl true
  def validate(p) do
    with :ok <- str(p, "accountRef"),
         :ok <- int(p, "concurrency", 2, 50),
         do: int(p, "amountSats", 1, 2_100_000_000_000_000)
  end

  @impl true
  def run(p, ctx) do
    with {:ok, ref} <- Context.resolve(ctx, p["accountRef"]) do
      results =
        1..p["concurrency"]
        |> Task.async_stream(
          fn i ->
            SatOps.Ledger.request_withdrawal(ctx.env.id, ref, p["amountSats"], 0, "#{ctx.run.id}:concurrent:#{i}", nil)
          end,
          max_concurrency: p["concurrency"],
          timeout: 30_000
        )
        |> Enum.map(fn
          {:ok, {:ok, _j, _}} -> :accepted
          {:ok, {:error, :insufficient_funds}} -> :rejected
          {:ok, {:error, other}} -> {:error, other}
          {:exit, reason} -> {:error, reason}
        end)

      accepted = Enum.count(results, &(&1 == :accepted))
      rejected = Enum.count(results, &(&1 == :rejected))
      errors = Enum.count(results, &match?({:error, _}, &1))

      {:ok,
       %{
         "accepted" => accepted,
         "rejected" => rejected,
         "errors" => errors,
         "refs" => %{"concurrent_withdrawals_accepted" => accepted}
       }}
    end
  end
end

defmodule SatOps.Experiments.Actions.Ledger.PostWithCrash do
  use SatOps.Experiments.Actions.Base, name: "ledger.post_with_crash", idempotency: :keyed, capabilities: ["ledger"]
  alias SatOps.Ledger.Rules

  @impl true
  def validate(p) do
    with :ok <- str(p, "fromRef"), :ok <- str(p, "toRef"), :ok <- int(p, "amountSats", 1, 1_000_000_000) do
      if p["crash"] in ["before_commit", "after_commit"],
        do: :ok,
        else: {:error, "crash must be before_commit or after_commit"}
    end
  end

  @impl true
  def run(p, ctx) do
    with {:ok, from} <- Context.resolve(ctx, p["fromRef"]),
         {:ok, to} <- Context.resolve(ctx, p["toRef"]),
         {:ok, draft} <-
           Rules.build("internal_transfer", %{
             operation_id: "crash-test:#{ctx.run.id}",
             from_ref: from,
             to_ref: to,
             amount_sats: p["amountSats"]
           }) do
      env_id = ctx.env.id
      parent = self()

      {pid, ref} =
        spawn_monitor(fn ->
          SatOps.Repo.transaction(fn ->
            {:ok, _, _} = SatOps.Ledger.post(env_id, draft)
            if p["crash"] == "before_commit", do: exit(:simulated_worker_crash)
          end)

          send(parent, :committed)
          exit(:simulated_worker_crash)
        end)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        15_000 -> Process.exit(pid, :kill)
      end

      committed = receive do: (:committed -> true), after: (0 -> false)
      before = SatOps.Ledger.list_journals(env_id, operation_id: draft.operation_id) |> length()
      retry = SatOps.Ledger.post(env_id, draft)
      after_count = SatOps.Ledger.list_journals(env_id, operation_id: draft.operation_id) |> length()

      {:ok,
       %{
         "crash" => p["crash"],
         "committedBeforeCrash" => committed,
         "journalsAfterCrash" => before,
         "retryResult" => retry |> elem(0) |> to_string(),
         "retryStatus" => if(match?({:ok, _, _}, retry), do: retry |> elem(2) |> to_string()),
         "journalsAfterRetry" => after_count
       }}
    end
  end
end

defmodule SatOps.Experiments.Actions.Events.Helpers do
  import Ecto.Query

  def run_events(ctx, types) do
    SatOps.Repo.all(
      from e in SatOps.Events.Event,
        where: e.environment_id == ^ctx.env.id and e.event_type in ^types and e.observed_at >= ^ctx.run.started_at,
        order_by: e.seq
    )
  end
end

defmodule SatOps.Experiments.Actions.Events.DuplicateDelivery do
  use SatOps.Experiments.Actions.Base,
    name: "events.duplicate_delivery",
    idempotency: :natural,
    capabilities: ["events"]

  alias SatOps.Experiments.Actions.Events.Helpers

  @impl true
  def validate(p), do: int(p, "times", 1, 500)

  @impl true
  def run(p, ctx) do
    events = Helpers.run_events(ctx, ["transaction.confirmed", "transaction.observed", "block.connected"])

    for _ <- 1..p["times"], event <- events do
      {:ok, :ok} = SatOps.Repo.transaction(fn -> SatOps.Ledger.ChainConsumer.handle(event) end)
    end

    {:ok, %{"events" => length(events), "deliveries" => length(events) * p["times"]}}
  end
end

defmodule SatOps.Experiments.Actions.Events.OutOfOrderDelivery do
  use SatOps.Experiments.Actions.Base,
    name: "events.out_of_order_delivery",
    idempotency: :natural,
    capabilities: ["events"]

  alias SatOps.Experiments.Actions.Events.Helpers

  @impl true
  def run(_p, ctx) do
    events =
      Helpers.run_events(ctx, [
        "transaction.confirmed",
        "transaction.observed",
        "transaction.unconfirmed",
        "block.connected"
      ])

    :rand.seed(:exsss, ctx.seed)
    shuffled = Enum.shuffle(events) |> Enum.reverse()

    Enum.each(shuffled, fn event ->
      {:ok, :ok} = SatOps.Repo.transaction(fn -> SatOps.Ledger.ChainConsumer.handle(event) end)
    end)

    {:ok, %{"events" => length(events), "order" => Enum.map(shuffled, & &1.seq)}}
  end
end

defmodule SatOps.Experiments.Actions.SatWatch.SuspendMonitor do
  use SatOps.Experiments.Actions.Base,
    name: "satwatch.suspend_monitor",
    idempotency: :natural,
    capabilities: ["satwatch"]

  @impl true
  def validate(p), do: str(p, "node")

  @impl true
  def run(p, ctx) do
    with {:ok, integration, _rpc} <- Context.node(ctx, p["node"]) do
      SatOps.Blockchain.NodeSupervisor.stop_node(integration.id)

      {:ok,
       %{
         "node" => p["node"],
         "monitor" => "stopped",
         "note" => "ZeroMQ notifications published meanwhile are lost by design"
       }}
    end
  end
end

defmodule SatOps.Experiments.Actions.SatWatch.ResumeMonitor do
  use SatOps.Experiments.Actions.Base,
    name: "satwatch.resume_monitor",
    idempotency: :natural,
    capabilities: ["satwatch"]

  @impl true
  def validate(p), do: str(p, "node")

  @impl true
  def run(p, ctx) do
    with {:ok, integration, _rpc} <- Context.node(ctx, p["node"]) do
      SatOps.Blockchain.NodeSupervisor.restart_node(integration)
      {:ok, %{"node" => p["node"], "monitor" => "running"}}
    end
  end
end

defmodule SatOps.Experiments.Actions.SatWatch.SyncNow do
  use SatOps.Experiments.Actions.Base, name: "satwatch.sync_now", idempotency: :natural, capabilities: ["satwatch"]

  @impl true
  def run(p, ctx) do
    deadline = System.monotonic_time(:millisecond) + (p["timeoutMs"] || 60_000)
    wait(ctx, deadline, 1)
  end

  defp wait(ctx, deadline, attempt) do
    with {:ok, _i, rpc} <- Context.node(ctx, nil),
         {:ok, best} <- RPC.call(rpc, "getbestblockhash") do
      SatOps.Blockchain.Workers.SyncChain.enqueue(ctx.env.id, "experiment")
      tip = SatOps.Blockchain.tip(ctx.env.id)

      cond do
        tip && tip.hash == best ->
          {:ok, %{"tip" => best, "height" => tip.height}}

        System.monotonic_time(:millisecond) > deadline ->
          {:error, "local chain did not reach node tip #{best} before timeout"}

        true ->
          Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 300, max_ms: 2_000, jitter: 0.1))
          wait(ctx, deadline, attempt + 1)
      end
    else
      {:error, reason} ->
        if System.monotonic_time(:millisecond) > deadline do
          {:error, rpc_error(reason)}
        else
          Process.sleep(1_000)
          wait(ctx, deadline, attempt + 1)
        end
    end
  end
end

defmodule SatOps.Experiments.Actions.Platform.RestartProcesses do
  use SatOps.Experiments.Actions.Base,
    name: "platform.restart_processes",
    idempotency: :natural,
    capabilities: ["platform"]

  @impl true
  def run(_p, _ctx) do
    before = SatOps.Blockchain.NodeSupervisor.running() |> length()
    pid = Process.whereis(SatOps.Blockchain.NodeSupervisor)
    :ok = Supervisor.terminate_child(SatOps.Supervisor, SatOps.Blockchain.NodeSupervisor)
    {:ok, _} = Supervisor.restart_child(SatOps.Supervisor, SatOps.Blockchain.NodeSupervisor)
    SatOps.Blockchain.NodeSupervisor.start_all()
    after_count = SatOps.Blockchain.NodeSupervisor.running() |> length()

    {:ok,
     %{
       "monitorsBefore" => before,
       "monitorsAfter" => after_count,
       "supervisorReplaced" => Process.whereis(SatOps.Blockchain.NodeSupervisor) != pid,
       "scope" => "supervised processes restarted; durable state is read back from PostgreSQL"
     }}
  end
end

defmodule SatOps.Experiments.Actions.Load.GenerateTransactions do
  use SatOps.Experiments.Actions.Base,
    name: "load.generate_transactions",
    idempotency: :unsafe,
    capabilities: ["bitcoin.rpc"]

  @impl true
  def validate(p), do: int(p, "count", 1, 500)

  @impl true
  def run(p, ctx) do
    wallet = p["fromWallet"] || "satlab"

    with {:ok, rpc} <- Context.rpc(ctx, p["node"], wallet),
         {:ok, address} <- RPC.call(rpc, "getnewaddress", ["load", "bech32"]) do
      :rand.seed(:exsss, ctx.seed)
      started = System.monotonic_time(:millisecond)

      txids =
        for _ <- 1..p["count"] do
          sats = 10_000 + :rand.uniform(90_000)

          case RPC.call(rpc, "sendtoaddress", [address, RPC.sats_to_btc(sats)]) do
            {:ok, txid} -> txid
            _ -> nil
          end
        end

      sent = Enum.reject(txids, &is_nil/1)

      {:ok,
       %{
         "sent" => length(sent),
         "failed" => p["count"] - length(sent),
         "durationMs" => System.monotonic_time(:millisecond) - started
       }}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end
end

defmodule SatOps.Experiments.Actions.Kubernetes.Helpers do
  def result({:ok, _}, info), do: {:ok, info}
  def result({:error, reason}, _info), do: {:error, inspect(reason)}
end

defmodule SatOps.Experiments.Actions.Kubernetes.RestartWorkload do
  use SatOps.Experiments.Actions.Base,
    name: "kubernetes.restart_workload",
    idempotency: :natural,
    capabilities: ["kubernetes.restart_workload"]

  alias SatOps.Experiments.Actions.Kubernetes.Helpers

  @impl true
  def validate(p), do: with(:ok <- str(p, "namespace"), do: str(p, "name"))

  @impl true
  def run(p, _ctx) do
    SatOps.Infrastructure.Kubernetes.restart_workload(p["namespace"], p["kind"] || "Deployment", p["name"])
    |> Helpers.result(%{"restarted" => p["name"]})
  end
end

defmodule SatOps.Experiments.Actions.Kubernetes.DeletePod do
  use SatOps.Experiments.Actions.Base,
    name: "kubernetes.delete_pod",
    idempotency: :natural,
    capabilities: ["kubernetes.delete_pod"]

  alias SatOps.Experiments.Actions.Kubernetes.Helpers

  @impl true
  def validate(p), do: with(:ok <- str(p, "namespace"), do: str(p, "name"))

  @impl true
  def run(p, _ctx),
    do:
      SatOps.Infrastructure.Kubernetes.delete_pod(p["namespace"], p["name"])
      |> Helpers.result(%{"deleted" => p["name"]})
end

defmodule SatOps.Experiments.Actions.Kubernetes.ScaleWorkload do
  use SatOps.Experiments.Actions.Base,
    name: "kubernetes.scale_workload",
    idempotency: :natural,
    capabilities: ["kubernetes.scale_workload"]

  alias SatOps.Experiments.Actions.Kubernetes.Helpers

  @impl true
  def validate(p), do: with(:ok <- str(p, "namespace"), :ok <- str(p, "name"), do: int(p, "replicas", 0, 5))

  @impl true
  def run(p, _ctx) do
    SatOps.Infrastructure.Kubernetes.scale_workload(p["namespace"], p["kind"] || "Deployment", p["name"], p["replicas"])
    |> Helpers.result(%{"scaled" => p["name"], "replicas" => p["replicas"]})
  end
end

defmodule SatOps.Experiments.Actions.Kubernetes.IsolateWorkload do
  use SatOps.Experiments.Actions.Base,
    name: "kubernetes.isolate_workload",
    idempotency: :natural,
    capabilities: ["kubernetes.isolate_workload"]

  alias SatOps.Experiments.Actions.Kubernetes.Helpers

  @impl true
  def validate(p), do: with(:ok <- str(p, "namespace"), do: str(p, "app"))

  @impl true
  def run(p, ctx) do
    if p["remove"] do
      SatOps.Infrastructure.Kubernetes.remove_isolation(p["namespace"], p["app"])
      |> Helpers.result(%{"isolated" => false})
    else
      SatOps.Infrastructure.Kubernetes.isolate_workload(p["namespace"], p["app"], ctx.run.id)
      |> Helpers.result(%{"isolated" => true})
    end
  end
end

defmodule SatOps.Experiments.Actions.Reconciliation.Run do
  use SatOps.Experiments.Actions.Base,
    name: "reconciliation.run",
    idempotency: :natural,
    capabilities: ["reconciliation"]

  @impl true
  def run(p, ctx) do
    {:ok, run} = SatOps.Reconciliation.enqueue(ctx.env.id, "experiment")
    deadline = System.monotonic_time(:millisecond) + (p["timeoutMs"] || 120_000)
    wait(run.id, deadline, 1)
  end

  defp wait(id, deadline, attempt) do
    run = SatOps.Reconciliation.get_run(id)

    cond do
      run.status in ["completed", "incomplete", "failed"] ->
        {:ok,
         %{
           "runId" => run.id,
           "status" => run.status,
           "summary" => run.summary,
           "refs" => %{"last_reconciliation" => run.id}
         }}

      System.monotonic_time(:millisecond) > deadline ->
        {:error, "reconciliation #{id} did not finish before timeout"}

      true ->
        Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 300, max_ms: 2_000, jitter: 0.1))
        wait(id, deadline, attempt + 1)
    end
  end
end

defmodule SatOps.Experiments.Actions.Assert.Evaluate do
  use SatOps.Experiments.Actions.Base, name: "assert.evaluate", idempotency: :natural, capabilities: []

  @impl true
  def validate(p), do: SatOps.Experiments.Assertions.validate(p["assertion"] || %{})

  @impl true
  def run(p, ctx) do
    case SatOps.Experiments.Assertions.evaluate(p["assertion"], ctx) do
      %{outcome: "passed"} = r -> {:ok, %{"assertion" => stringify(r)}}
      r -> {:error, "assertion #{r.type} #{r.outcome}: #{r.message}"}
    end
  end

  defp stringify(r), do: Map.new(r, fn {k, v} -> {to_string(k), v} end)
end

defmodule SatOps.Experiments.Actions.Wait.Duration do
  use SatOps.Experiments.Actions.Base, name: "wait.duration", idempotency: :natural, capabilities: []

  @impl true
  def validate(p), do: int(p, "seconds", 1, 120)

  @impl true
  def run(p, _ctx) do
    Process.sleep(p["seconds"] * 1000)
    {:ok, %{"waitedSeconds" => p["seconds"]}}
  end
end
