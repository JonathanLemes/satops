defmodule SatOps.ConfigurationTest do
  use SatOps.DataCase
  alias SatOps.Configuration

  defp env_doc(name, confirmations \\ 3) do
    %{
      "apiVersion" => "satops.io/v1alpha1",
      "kind" => "Environment",
      "metadata" => %{"name" => name},
      "spec" => %{
        "network" => %{"type" => "regtest", "nodes" => 2},
        "ledger" => %{"asset" => "BTC", "confirmationPolicy" => %{"requiredConfirmations" => confirmations}},
        "safety" => %{"allowMainnet" => false, "allowPublicPeers" => false}
      }
    }
  end

  test "validation reports schema errors with paths" do
    doc = put_in(env_doc("bad"), ["spec", "network", "type"], "mainnet")
    assert {:error, errors} = Configuration.validate(doc)
    assert Enum.any?(errors, &(&1.path =~ "/spec/network/type"))
    doc = put_in(env_doc("bad2"), ["spec", "safety", "allowMainnet"], true)
    assert {:error, _} = Configuration.validate(doc)
    assert {:error, _} = Configuration.validate(put_in(env_doc("bad3"), ["spec", "unknownField"], 1))
  end

  test "apply is idempotent and creates revisions only when the spec changes" do
    admin = user()
    assert {:ok, %{changed: true, resource: r}} = Configuration.apply_document(env_doc("cfg-a"), actor: admin)
    assert r.status == "applied" and r.applied_revision == 1
    assert {:ok, %{changed: false}} = Configuration.apply_document(env_doc("cfg-a"), actor: admin)
    assert SatOps.Environments.get_by_slug("cfg-a").required_confirmations == 3

    assert {:ok, %{changed: true, resource: r2}} =
             Configuration.apply_document(env_doc("cfg-a", 6), actor: admin, expected_revision: 1)

    assert r2.desired_revision == 2
    assert SatOps.Environments.get_by_slug("cfg-a").required_confirmations == 6
  end

  test "optimistic concurrency rejects stale writers" do
    admin = user()
    {:ok, _} = Configuration.apply_document(env_doc("cfg-b"), actor: admin)
    {:ok, _} = Configuration.apply_document(env_doc("cfg-b", 4), actor: admin, expected_revision: 1)

    assert {:error, {:conflict, 2}} =
             Configuration.apply_document(env_doc("cfg-b", 5), actor: admin, expected_revision: 1)
  end

  test "plan shows the diff and impact without applying" do
    {:ok, _} = Configuration.apply_document(env_doc("cfg-c"), actor: nil)
    {:ok, plan} = Configuration.plan(env_doc("cfg-c", 9))
    assert plan.action == "update"

    assert [%{op: "replace", path: "/spec/ledger/confirmationPolicy/requiredConfirmations", old: 3, new: 9}] =
             plan.changes

    assert Enum.any?(plan.impact, &(&1 =~ "never reinterpreted"))
    assert SatOps.Environments.get_by_slug("cfg-c").required_confirmations == 3
  end

  test "yaml round trip through the canonical emitter preserves the document" do
    doc = env_doc("cfg-d")
    yaml = Configuration.Yaml.encode(doc)
    assert {:ok, ^doc} = Configuration.parse(yaml)
  end

  test "experiment scenarios reject actions outside the whitelist" do
    doc = %{
      "apiVersion" => "satops.io/v1alpha1",
      "kind" => "Experiment",
      "metadata" => %{"name" => "evil"},
      "spec" => %{
        "title" => "x",
        "steps" => [%{"id" => "s1", "action" => "shell.exec", "params" => %{"cmd" => "rm -rf /"}}]
      }
    }

    assert {:error, [%{message: msg}]} = Configuration.validate(doc)
    assert msg =~ "whitelist"
  end
end

defmodule SatOps.BundledResourcesTest do
  use SatOps.DataCase

  test "every bundled scenario is valid and uses only whitelisted actions" do
    files = Path.wildcard(Path.expand("../../../../../examples/scenarios/*.yaml", __DIR__))
    assert length(files) >= 13

    for file <- files do
      assert {:ok, %{"kind" => "Experiment"}} = SatOps.Configuration.parse(File.read!(file)), file
    end
  end

  test "bootstrap resources satisfy their JSON Schemas" do
    files = Path.wildcard(Path.expand("../../../../../examples/environments/bootstrap/*.yaml", __DIR__))
    assert files != []

    for file <- files do
      {:ok, doc} = SatOps.Configuration.Yaml.parse(File.read!(file))
      assert :ok = SatOps.Configuration.Schemas.validate(doc["kind"], doc), file
    end
  end
end
