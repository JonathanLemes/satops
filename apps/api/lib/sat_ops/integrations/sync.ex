defmodule SatOps.Integrations.Sync do
  require Logger
  alias SatOps.{Integrations, Repo, WalletMonitoring}
  alias SatOps.Integrations.Adapters.DemoFintech

  def sync_environment(environment_id) do
    environment_id
    |> Integrations.list(kind: "demo_fintech", enabled: true)
    |> Enum.each(&sync_deposit_addresses/1)
  end

  def sync_deposit_addresses(integration) do
    with {:ok, token} <- Integrations.credentials(integration),
         {:ok, %{body: %{"addresses" => addresses}}} <-
           DemoFintech.call(integration, token, :get, "/v1/deposit-addresses") do
      addresses
      |> Enum.group_by(& &1["customerId"], & &1["address"])
      |> Enum.each(fn {customer, addrs} -> upsert_wallet(integration, customer, addrs) end)

      :ok
    else
      error ->
        Logger.warning("deposit address sync failed for #{integration.name}: #{inspect(error)}")
        error
    end
  end

  defp upsert_wallet(integration, customer, addresses) do
    name = "#{integration.name}:#{customer}"

    case Repo.get_by(WalletMonitoring.Wallet, environment_id: integration.environment_id, name: name) do
      nil ->
        WalletMonitoring.create_wallet(
          %{
            environment_id: integration.environment_id,
            name: name,
            kind: "addresses",
            group_name: integration.name,
            account_ref: customer,
            labels: ["customer-deposits", "synced"],
            addresses: addresses
          },
          nil
        )

      wallet ->
        known = MapSet.new(Repo.preload(wallet, :addresses).addresses, & &1.address)

        for a <- addresses, not MapSet.member?(known, a) do
          WalletMonitoring.add_address(wallet, a, nil, nil)
        end
    end
  end
end
