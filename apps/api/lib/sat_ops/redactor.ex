defmodule SatOps.Redactor do
  @sensitive ~r/(pass(word)?|secret|token|api[_-]?key|authorization|cookie|private|seed|mnemonic|xprv|tprv|credential)/i

  def redact(%DateTime{} = dt), do: dt
  def redact(%{__struct__: _} = struct), do: struct |> Map.from_struct() |> Map.drop([:__meta__]) |> redact()

  def redact(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      if sensitive_key?(k), do: {k, "[REDACTED]"}, else: {k, redact(v)}
    end)
  end

  def redact(list) when is_list(list), do: Enum.map(list, &redact/1)

  def redact(value) when is_binary(value) do
    Regex.replace(~r/(https?:\/\/)[^\/\s:@]+:[^\/\s@]+@/, value, "\\1[REDACTED]@")
  end

  def redact(value), do: value

  def sensitive_key?(key), do: Regex.match?(@sensitive, to_string(key))
end
