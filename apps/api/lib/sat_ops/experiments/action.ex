defmodule SatOps.Experiments.Action do
  @type idempotency :: :natural | :keyed | :verifiable | :compensable | :unsafe

  @callback name() :: String.t()
  @callback idempotency() :: idempotency()
  @callback capabilities() :: [String.t()]
  @callback validate(map()) :: :ok | {:error, String.t()}
  @callback run(map(), map()) :: {:ok, map()} | {:error, term()}
  @callback verify(map(), map(), map()) :: {:ok, map()} | :not_done | :unknown
  @optional_callbacks verify: 3

  alias SatOps.Experiments.Actions

  @registry [
    Actions.Bitcoin.CreateWallet,
    Actions.Bitcoin.CreateAddress,
    Actions.Bitcoin.MineBlocks,
    Actions.Bitcoin.SendTransaction,
    Actions.Bitcoin.WaitConfirmations,
    Actions.Bitcoin.DisconnectPeer,
    Actions.Bitcoin.ConnectPeer,
    Actions.Bitcoin.ReorganizeChain,
    Actions.Bitcoin.StopNode,
    Actions.Bitcoin.EnsureFunds,
    Actions.Integration.CreateCustomer,
    Actions.Integration.RequestDepositAddress,
    Actions.Integration.RequestWithdrawal,
    Actions.Integration.SetFault,
    Actions.Integration.DeliverEvent,
    Actions.Integration.RedeliverEvent,
    Actions.Integration.DelayResponse,
    Actions.Integration.SimulateTimeout,
    Actions.Integration.ReorderEvents,
    Actions.Integration.Sync,
    Actions.Ledger.RequestWithdrawal,
    Actions.Ledger.ConcurrentWithdrawals,
    Actions.Ledger.PostWithCrash,
    Actions.Events.DuplicateDelivery,
    Actions.Events.OutOfOrderDelivery,
    Actions.SatWatch.SuspendMonitor,
    Actions.SatWatch.ResumeMonitor,
    Actions.SatWatch.SyncNow,
    Actions.Platform.RestartProcesses,
    Actions.Load.GenerateTransactions,
    Actions.Kubernetes.RestartWorkload,
    Actions.Kubernetes.DeletePod,
    Actions.Kubernetes.ScaleWorkload,
    Actions.Kubernetes.IsolateWorkload,
    Actions.Reconciliation.Run,
    Actions.Assert.Evaluate,
    Actions.Wait.Duration
  ]

  def registry, do: Map.new(@registry, &{&1.name(), &1})
  def fetch(name), do: Map.fetch(registry(), name)

  def describe do
    Enum.map(@registry, fn m -> %{name: m.name(), idempotency: m.idempotency(), capabilities: m.capabilities()} end)
  end

  def runtime_capabilities(environment_id) do
    nodes = SatOps.Integrations.list(environment_id, kind: "bitcoin_core", enabled: true)
    fintech = SatOps.Integrations.list(environment_id, kind: "demo_fintech", enabled: true)

    base = ["ledger", "reconciliation", "events", "satwatch", "platform"]
    btc = if nodes != [], do: ["bitcoin.rpc"], else: []
    multi = if length(nodes) >= 2, do: ["bitcoin.multi_node"], else: []
    fin = if fintech != [], do: ["integration.demo_fintech"], else: []

    k8s =
      if SatOps.Infrastructure.Kubernetes.available?(),
        do: [
          "kubernetes.restart_workload",
          "kubernetes.delete_pod",
          "kubernetes.scale_workload",
          "kubernetes.isolate_workload"
        ],
        else: []

    base ++ btc ++ multi ++ fin ++ k8s
  end
end
