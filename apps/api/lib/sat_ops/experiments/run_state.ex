defmodule SatOps.Experiments.RunState do
  @terminal ~w(passed failed inconclusive aborted)

  @transitions %{
    "created" => ~w(validating aborted),
    "validating" => ~w(provisioning failed aborted),
    "provisioning" => ~w(preparing cleaning_up failed inconclusive aborted),
    "preparing" => ~w(running cleaning_up aborted),
    "running" => ~w(verifying cleaning_up aborted),
    "verifying" => ~w(cleaning_up aborted),
    "cleaning_up" => ~w(passed failed inconclusive aborted),
    "passed" => [],
    "failed" => [],
    "inconclusive" => [],
    "aborted" => []
  }

  def terminal?(status), do: status in @terminal
  def terminal, do: @terminal
  def statuses, do: Map.keys(@transitions)

  def transition(from, from), do: {:ok, from}

  def transition(from, to) do
    if to in Map.get(@transitions, from, []), do: {:ok, to}, else: {:error, {:invalid_transition, from, to}}
  end

  def phase_status("prepare"), do: "preparing"
  def phase_status("run"), do: "running"
  def phase_status("verify"), do: "verifying"
  def phase_status("cleanup"), do: "cleaning_up"

  def path(from, to) do
    order = ~w(created validating provisioning preparing running verifying cleaning_up)
    fi = Enum.find_index(order, &(&1 == from))
    ti = Enum.find_index(order, &(&1 == to))
    if fi && ti && ti > fi, do: Enum.slice(order, (fi + 1)..ti), else: [to]
  end

  def outcome(steps, assertions, aborted?) do
    cond do
      aborted? ->
        {"aborted", "aborted by user"}

      Enum.any?(steps, &(&1.status == "unknown")) ->
        {"inconclusive", "an interrupted action has an unknown outcome and was not repeated"}

      Enum.any?(steps, &(&1.status == "failed" and &1.phase != "cleanup")) ->
        {"failed", first_failure(steps)}

      Enum.any?(assertions, &(&1.outcome in ["source_unavailable", "error"])) ->
        {"inconclusive", "an assertion could not be evaluated"}

      Enum.any?(assertions, &(&1.outcome in ["false", "timed_out"])) ->
        {"failed", "#{Enum.count(assertions, &(&1.outcome in ["false", "timed_out"]))} assertion(s) failed"}

      true ->
        {"passed", "all steps succeeded and all assertions passed"}
    end
  end

  defp first_failure(steps) do
    s = Enum.find(steps, &(&1.status == "failed"))
    "step #{s.step_key} failed: #{s.failure_reason}"
  end
end
