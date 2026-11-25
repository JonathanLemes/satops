defmodule SatOpsWeb.GraphQL.Scalars do
  use Absinthe.Schema.Notation

  scalar :json, name: "JSON" do
    serialize &stringify_keys/1
    parse &parse_json/1
  end

  scalar :sats, name: "Sats" do
    description "Integer amount of satoshis (safe up to 2^53)"
    serialize & &1
    parse &parse_sats/1
  end

  defp parse_json(%Absinthe.Blueprint.Input.String{value: v}) do
    case Jason.decode(v) do
      {:ok, d} -> {:ok, d}
      _ -> :error
    end
  end

  defp parse_json(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  defp parse_json(node), do: {:ok, to_plain(node)}

  defp to_plain(%Absinthe.Blueprint.Input.Object{fields: fields}),
    do: Map.new(fields, fn f -> {f.name, to_plain(f.input_value)} end)

  defp to_plain(%Absinthe.Blueprint.Input.List{items: items}), do: Enum.map(items, &to_plain/1)
  defp to_plain(%Absinthe.Blueprint.Input.Value{normalized: n}), do: to_plain(n)
  defp to_plain(%Absinthe.Blueprint.Input.RawValue{content: c}), do: to_plain(c)
  defp to_plain(%Absinthe.Blueprint.Input.Null{}), do: nil
  defp to_plain(%{value: v}), do: v
  defp to_plain(other), do: other

  defp parse_sats(%Absinthe.Blueprint.Input.Integer{value: v}) when v >= 0, do: {:ok, v}
  defp parse_sats(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  defp parse_sats(_), do: :error

  def stringify_keys(%DateTime{} = d), do: DateTime.to_iso8601(d)
  def stringify_keys(%Decimal{} = d), do: Decimal.to_string(d)
  def stringify_keys(%{__struct__: _} = s), do: s |> Map.from_struct() |> Map.drop([:__meta__]) |> stringify_keys()
  def stringify_keys(m) when is_map(m), do: Map.new(m, fn {k, v} -> {to_string(k), stringify_keys(v)} end)
  def stringify_keys(l) when is_list(l), do: Enum.map(l, &stringify_keys/1)
  def stringify_keys(v), do: v
end

defmodule SatOpsWeb.GraphQL.Authorize do
  @behaviour Absinthe.Middleware

  def call(%{state: :resolved} = res, _), do: res

  def call(res, {action, env_key}) do
    user = res.context[:current_user]
    env_id = env_key && environment_id(res, env_key)

    case SatOps.Identity.authorize(user, action, env_id) do
      :ok ->
        res

      {:error, code} ->
        Absinthe.Resolution.put_result(
          res,
          {:error, message: to_string(code), extensions: %{code: String.upcase(to_string(code))}}
        )
    end
  end

  def call(res, action), do: call(res, {action, nil})

  defp environment_id(res, {:arg, key}), do: res.arguments[key]
  defp environment_id(res, :environment_id), do: res.arguments[:environment_id]
  defp environment_id(res, :source), do: Map.get(res.source, :environment_id)
end

defmodule SatOpsWeb.GraphQL.Errors do
  @behaviour Absinthe.Middleware

  def call(%{errors: errors} = res, _) do
    %{res | errors: Enum.flat_map(errors, &format/1)}
  end

  def format(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(inspect(v))) end)
    end)
    |> flatten()
    |> Enum.map(fn {field, msg} ->
      %{message: "#{field} #{msg}", extensions: %{code: "VALIDATION_ERROR", field: field}}
    end)
  end

  def format({:conflict, rev}),
    do: [
      %{
        message: "configuration changed concurrently (current revision #{rev})",
        extensions: %{code: "CONFLICT", currentRevision: rev}
      }
    ]

  def format(:stale),
    do: [%{message: "resource changed concurrently; reload and try again", extensions: %{code: "CONFLICT"}}]

  def format(:not_found), do: [%{message: "not found", extensions: %{code: "NOT_FOUND"}}]

  def format(:insufficient_funds),
    do: [%{message: "insufficient available balance", extensions: %{code: "INSUFFICIENT_FUNDS"}}]

  def format(:idempotency_conflict),
    do: [%{message: "idempotency key reused with different parameters", extensions: %{code: "IDEMPOTENCY_CONFLICT"}}]

  def format(list) when is_list(list) do
    if Enum.all?(list, &is_map/1) and Enum.all?(list, &Map.has_key?(&1, :message)) do
      Enum.map(list, fn e ->
        %{
          message: e.message,
          extensions: %{code: "INVALID_CONFIGURATION", path: e[:path], line: e[:line], column: e[:column]}
        }
      end)
    else
      [%{message: inspect(list), extensions: %{code: "ERROR"}}]
    end
  end

  def format(%{message: _} = m) when not is_struct(m), do: [m]
  def format(msg) when is_binary(msg), do: [%{message: msg, extensions: %{code: "DOMAIN_ERROR"}}]

  def format(atom) when is_atom(atom),
    do: [%{message: to_string(atom), extensions: %{code: atom |> to_string() |> String.upcase()}}]

  def format({code, detail}) when is_atom(code),
    do: [%{message: "#{code}: #{inspect(detail)}", extensions: %{code: code |> to_string() |> String.upcase()}}]

  def format(other), do: [%{message: inspect(other), extensions: %{code: "ERROR"}}]

  defp flatten(map, prefix \\ nil) do
    Enum.flat_map(map, fn
      {k, v} when is_map(v) ->
        flatten(v, join(prefix, k))

      {k, msgs} when is_list(msgs) ->
        Enum.flat_map(msgs, fn m -> if is_map(m), do: flatten(m, join(prefix, k)), else: [{join(prefix, k), m}] end)
    end)
  end

  defp join(nil, k), do: to_string(k)
  defp join(p, k), do: "#{p}.#{k}"
end

defmodule SatOpsWeb.GraphQL.Loader do
  def new do
    Dataloader.new() |> Dataloader.add_source(:repo, Dataloader.Ecto.new(SatOps.Repo))
  end
end

defmodule SatOpsWeb.GraphQL.Helpers do
  def ok(v), do: {:ok, v}

  def actor(%{context: %{current_user: user}}), do: user

  def wrap({:ok, v}), do: {:ok, v}
  def wrap({:ok, v, _}), do: {:ok, v}
  def wrap({:error, reason}), do: {:error, reason}
  def wrap(nil), do: {:error, :not_found}
  def wrap(v), do: {:ok, v}

  def authorize_env(res, action, env_id) do
    SatOps.Identity.authorize(actor(res), action, env_id)
  end
end
