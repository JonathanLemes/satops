defmodule SatOps.PureMiscTest do
  use ExUnit.Case, async: true
  alias SatOps.{Backoff, Redactor}
  alias SatOps.Integrations.UrlPolicy
  alias SatOps.Experiments.RunState

  test "exponential backoff grows, is capped and jittered within bounds" do
    mid = fn -> 0.5 end
    assert Backoff.delay(1, base_ms: 100, rand: mid) == 100
    assert Backoff.delay(4, base_ms: 100, rand: mid) == 800
    assert Backoff.delay(30, base_ms: 100, max_ms: 5_000, rand: mid) == 5_000
    for _ <- 1..100, do: assert(Backoff.delay(3, base_ms: 100) in 320..480)
  end

  test "redaction hides secrets in nested structures and URLs" do
    out = Redactor.redact(%{"password" => "x", "nested" => %{"apiKey" => "k", "ok" => 1}, "url" => "http://u:p@host/x"})
    assert out["password"] == "[REDACTED]"
    assert out["nested"]["apiKey"] == "[REDACTED]"
    assert out["nested"]["ok"] == 1
    assert out["url"] == "http://[REDACTED]@host/x"
  end

  describe "SSRF protection" do
    test "only allowlisted hosts are accepted" do
      assert {:error, _} = UrlPolicy.validate_url("http://evil.example/x", allowed_hosts: ["demo-fintech"])
      assert {:error, _} = UrlPolicy.validate_url("file:///etc/passwd", allowed_hosts: ["demo-fintech"])

      assert {:ok, _} =
               UrlPolicy.validate_url("http://demo-fintech:8080",
                 allowed_hosts: ["demo-fintech"],
                 resolver: fn _ -> {:ok, [{10, 0, 0, 5}]} end
               )
    end

    test "allowlisted names that resolve to metadata or link-local addresses are rejected" do
      resolver = fn _ -> {:ok, [{169, 254, 169, 254}]} end

      assert {:error, msg} =
               UrlPolicy.validate_url("http://demo-fintech", allowed_hosts: ["demo-fintech"], resolver: resolver)

      assert msg =~ "forbidden"
      assert UrlPolicy.blocked_ip?({0, 0, 0, 0, 0, 0xFFFF, 0xA9FE, 0xA9FE})
      refute UrlPolicy.blocked_ip?({172, 18, 0, 2})
    end
  end

  describe "experiment state machine" do
    test "valid and invalid transitions" do
      assert {:ok, "validating"} = RunState.transition("created", "validating")
      assert {:error, _} = RunState.transition("created", "passed")
      assert {:error, _} = RunState.transition("passed", "running")
    end

    test "infrastructure failures never become a pass" do
      steps = [%{status: "succeeded", phase: "run"}]
      assert {"passed", _} = RunState.outcome(steps, [%{outcome: "passed"}], false)
      assert {"inconclusive", _} = RunState.outcome(steps, [%{outcome: "source_unavailable"}], false)
      assert {"failed", _} = RunState.outcome(steps, [%{outcome: "timed_out"}], false)
      assert {"inconclusive", _} = RunState.outcome([%{status: "unknown", phase: "run"}], [], false)
      assert {"aborted", _} = RunState.outcome(steps, [], true)
    end
  end
end
