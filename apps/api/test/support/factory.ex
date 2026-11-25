defmodule SatOps.Factory do
  alias SatOps.Repo

  def unique(prefix),
    do: "#{prefix}-#{System.unique_integer([:positive])}-#{Base.encode16(:crypto.strong_rand_bytes(3), case: :lower)}"

  def environment(attrs \\ %{}) do
    {:ok, env} =
      SatOps.Environments.create(
        Map.merge(%{slug: unique("env"), name: "Test", required_confirmations: 3}, attrs),
        nil
      )

    env
  end

  def user(role \\ "administrator", attrs \\ %{}) do
    {:ok, user} =
      SatOps.Identity.create_user(
        Map.merge(
          %{email: "#{unique("user")}@example.test", name: "Tester", password: "correct-horse-battery", role: role},
          attrs
        )
      )

    user
  end

  def post_transfer!(env, from, to, amount, key) do
    {:ok, _, _} = SatOps.Ledger.transfer(env.id, from, to, amount, key, nil)
  end

  def fund!(env, ref, amount, key \\ nil) do
    key = key || unique("fund")
    alias SatOps.Ledger.{Draft, Chart}

    draft = %Draft{
      operation_id: "fund:#{key}",
      entry_kind: "fund",
      rule_name: "test_funding",
      rule_version: 1,
      postings: [Draft.debit(Chart.onchain(), amount), Draft.credit(Chart.available(ref), amount)]
    }

    {:ok, journal, _} = SatOps.Ledger.post(env.id, draft)
    journal
  end

  def insert_tx!(env, txid, status, opts \\ []) do
    now = DateTime.utc_now()

    Repo.insert!(%SatOps.Blockchain.Transaction{
      environment_id: env.id,
      txid: txid,
      status: status,
      block_hash: opts[:block_hash],
      block_height: opts[:block_height],
      is_coinbase: false,
      first_seen_at: now,
      status_changed_at: now,
      version: 1
    })
  end
end
