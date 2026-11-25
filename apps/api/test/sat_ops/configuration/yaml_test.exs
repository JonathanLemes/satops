defmodule SatOps.Configuration.YamlTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias SatOps.Configuration.Yaml

  test "parses plain documents" do
    assert {:ok, %{"a" => 1, "b" => ["x", true, nil], "c" => %{"d" => "e"}}} =
             Yaml.parse("a: 1\nb: [x, true, null]\nc:\n  d: e\n")
  end

  test "rejects duplicate keys with a location" do
    assert {:error, [%{message: "duplicate key \"a\"", line: 2}]} = Yaml.parse("a: 1\na: 2\n")
  end

  test "rejects unsupported tags, anchors and aliases, multiple documents and oversized input" do
    assert {:error, _} = Yaml.parse("a: !!python/object x\n")
    assert {:error, [%{message: msg}]} = Yaml.parse("a: &x [1]\nb: *x\n")
    assert msg =~ "anchors"
    assert {:error, _} = Yaml.parse("a: 1\n---\nb: 2\n")
    assert {:error, _} = Yaml.parse(String.duplicate("a", 200_000))
  end

  test "quoted strings containing ampersands are not mistaken for anchors" do
    assert {:ok, %{"a" => "x & *y"}} = Yaml.parse(~s(a: "x & *y"\n))
  end

  test "emitter output is deterministic and orders resource keys" do
    doc = %{
      "spec" => %{"b" => 1, "a" => "true"},
      "kind" => "Environment",
      "apiVersion" => "satops.io/v1alpha1",
      "metadata" => %{"name" => "x"}
    }

    yaml = Yaml.encode(doc)
    assert String.starts_with?(yaml, "apiVersion: satops.io/v1alpha1\nkind: Environment\nmetadata:")
    assert {:ok, ^doc} = Yaml.parse(yaml)
  end

  property "round-trip without semantic loss" do
    key = string([?a..?z, ?A..?Z], min_length: 1, max_length: 8)

    scalar =
      one_of([
        integer(),
        boolean(),
        constant(nil),
        string(:printable, max_length: 20)
        |> filter(&(String.trim(&1) == &1 and not String.contains?(&1, ["\\", "\t"])))
      ])

    value = tree(scalar, fn child -> one_of([list_of(child, max_length: 3), map_of(key, child, max_length: 3)]) end)

    check all(doc <- map_of(key, value, min_length: 1, max_length: 5), max_runs: 200) do
      assert {:ok, ^doc} = Yaml.parse(Yaml.encode(doc))
    end
  end
end
