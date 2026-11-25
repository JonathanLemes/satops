defmodule SatOps.Integrations.Adapters.BitcoinCore do
  @behaviour SatOps.Integrations.Adapter
  alias SatOps.Integrations.ConfigValidation, as: V
  alias SatOps.Infrastructure.Bitcoin.RPC

  @impl true
  def capabilities, do: ["node.monitor", "bitcoin.rpc", "bitcoin.zmq", "bitcoin.wallet"]

  @impl true
  def validate_configuration(config) do
    config = Map.new(config, fn {k, v} -> {to_string(k), v} end)

    with :ok <-
           V.run(config, [
             {"host", &V.required_string/1},
             {"port", &V.port/1},
             {"zmqEndpoint", &V.url/1},
             {"timeoutMs", V.duration_ms(100, 60_000)},
             {"reconcileIntervalMs", V.duration_ms(1_000, 3_600_000)}
           ]),
         :ok <- host_allowed(config["host"]) do
      {:ok,
       %{
         "host" => config["host"],
         "port" => config["port"],
         "zmqEnabled" => Map.get(config, "zmqEnabled", is_binary(config["zmqEndpoint"])),
         "zmqEndpoint" => config["zmqEndpoint"],
         "timeoutMs" => config["timeoutMs"] || 5_000,
         "reconcileIntervalMs" => config["reconcileIntervalMs"] || 30_000,
         "priority" => config["priority"] || 100,
         "wallet" => config["wallet"]
       }}
    end
  end

  defp host_allowed(host) do
    case SatOps.Integrations.UrlPolicy.validate_host(host) do
      :ok -> :ok
      {:error, msg} -> {:error, [msg]}
    end
  end

  def rpc(integration, credentials) do
    {user, password} =
      case String.split(credentials || "", ":", parts: 2) do
        [u, p] -> {u, p}
        _ -> {"", ""}
      end

    RPC.new(
      url: "http://#{integration.config["host"]}:#{integration.config["port"]}",
      user: user,
      password: password,
      timeout: integration.config["timeoutMs"] || 5_000,
      wallet: integration.config["wallet"]
    )
  end

  @impl true
  def health_check(integration, credentials) do
    rpc = rpc(integration, credentials)

    with {{:ok, info}, latency} <- RPC.latency_call(rpc, "getblockchaininfo"),
         :ok <- SatOps.Environments.assert_regtest_chain(info["chain"]),
         {:ok, peers} <- RPC.call(rpc, "getconnectioncount"),
         {:ok, mempool} <- RPC.call(rpc, "getmempoolinfo") do
      {:ok,
       %{
         "chain" => info["chain"],
         "height" => info["blocks"],
         "bestHash" => info["bestblockhash"],
         "chainwork" => info["chainwork"],
         "initialBlockDownload" => info["initialblockdownload"],
         "peers" => peers,
         "mempoolSize" => mempool["size"],
         "latencyMs" => latency
       }}
    else
      {{:error, reason}, _latency} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end
end
