defmodule SatOps.Configuration.Schemas do
  def dir do
    case Application.get_env(:sat_ops, :config_schemas_dir) do
      :priv -> Application.app_dir(:sat_ops, "priv/config_schemas")
      nil -> Application.app_dir(:sat_ops, "priv/config_schemas")
      path -> path
    end
  end

  def raw(kind) do
    key = {__MODULE__, :raw, kind}

    case :persistent_term.get(key, nil) do
      nil ->
        schema = Path.join(dir(), "#{kind}.json") |> File.read!() |> Jason.decode!()
        :persistent_term.put(key, schema)
        schema

      schema ->
        schema
    end
  end

  def resolved(kind) do
    key = {__MODULE__, :resolved, kind}

    case :persistent_term.get(key, nil) do
      nil ->
        schema = kind |> raw() |> Map.delete("$id") |> ExJsonSchema.Schema.resolve()
        :persistent_term.put(key, schema)
        schema

      schema ->
        schema
    end
  end

  def validate(kind, doc) do
    case ExJsonSchema.Validator.validate(resolved(kind), doc) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error, Enum.map(errors, fn {msg, path} -> %{path: String.trim_leading(path, "#"), message: msg} end)}
    end
  end
end
