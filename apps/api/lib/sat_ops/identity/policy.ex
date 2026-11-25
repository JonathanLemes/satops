defmodule SatOps.Identity.Policy do
  @viewer ~w(workspace.customer environment.read blockchain.read wallet.read reconciliation.read alert.read dashboard.read dashboard.manage)a
  @auditor @viewer ++
             ~w(ledger.read audit.read experiment.read integration.read config.read reconciliation.export jobs.read workspace.engineering)a
  @engineer @auditor ++
              ~w(integration.manage wallet.manage reconciliation.run discrepancy.resolve experiment.run config.apply alert.manage environment.manage ledger.post)a
  @administrator @engineer ++ ~w(user.manage ledger.compensate secret.manage)a

  @permissions %{
    "viewer" => MapSet.new(@viewer),
    "auditor" => MapSet.new(@auditor),
    "engineer" => MapSet.new(@engineer),
    "administrator" => MapSet.new(@administrator)
  }

  def permissions(role), do: Map.get(@permissions, role, MapSet.new()) |> MapSet.to_list() |> Enum.sort()

  def allowed?(role, action) when is_binary(role) and is_atom(action) do
    @permissions |> Map.get(role, MapSet.new()) |> MapSet.member?(action)
  end

  def allowed?(_, _), do: false

  def effective_role(%{role: "administrator"}, _membership), do: "administrator"
  def effective_role(_user, nil), do: nil
  def effective_role(user, %{role: membership_role}), do: lower(user.role, membership_role)

  @rank %{"viewer" => 0, "auditor" => 1, "engineer" => 2, "administrator" => 3}

  defp lower(a, b), do: if(@rank[a] <= @rank[b], do: a, else: b)
end
