defmodule SatOps.Integrations.ConfigValidation do
  def run(config, checks) do
    errors =
      Enum.flat_map(checks, fn {key, check} ->
        value = Map.get(config, key)

        case check.(value) do
          :ok -> []
          {:error, msg} -> ["#{key}: #{msg}"]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  def required_string(v) when is_binary(v) and v != "", do: :ok
  def required_string(_), do: {:error, "is required"}

  def optional_string(nil), do: :ok
  def optional_string(v) when is_binary(v), do: :ok
  def optional_string(_), do: {:error, "must be a string"}

  def port(v) when is_integer(v) and v in 1..65_535, do: :ok
  def port(_), do: {:error, "must be an integer between 1 and 65535"}

  def duration_ms(min, max) do
    fn
      nil -> :ok
      v when is_integer(v) and v >= min and v <= max -> :ok
      _ -> {:error, "must be between #{min} and #{max} ms"}
    end
  end

  def url(nil), do: :ok

  def url(v) when is_binary(v) do
    case SatOps.Integrations.UrlPolicy.validate_url(v) do
      {:ok, _} -> :ok
      {:error, msg} -> {:error, msg}
    end
  end

  def url(_), do: {:error, "must be a URL"}

  def required_url(nil), do: {:error, "is required"}
  def required_url(v), do: url(v)

  def parse_duration(nil, default), do: default
  def parse_duration(v, _default) when is_integer(v), do: v

  def parse_duration(v, default) when is_binary(v) do
    case Regex.run(~r/^(\d+)(ms|s|m)$/, v) do
      [_, n, "ms"] -> String.to_integer(n)
      [_, n, "s"] -> String.to_integer(n) * 1000
      [_, n, "m"] -> String.to_integer(n) * 60_000
      _ -> default
    end
  end
end
