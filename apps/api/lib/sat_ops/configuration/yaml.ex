defmodule SatOps.Configuration.Yaml do
  @max_bytes 131_072
  @max_depth 24
  @max_nodes 5_000

  def parse(text) when is_binary(text) do
    cond do
      byte_size(text) > @max_bytes ->
        {:error, [%{message: "document is larger than #{div(@max_bytes, 1024)} KB", line: nil, column: nil}]}

      not String.valid?(text) ->
        {:error, [%{message: "document is not valid UTF-8", line: nil, column: nil}]}

      line = anchor_line(text) ->
        {:error, [%{message: "YAML anchors, aliases and merge keys are not supported", line: line, column: nil}]}

      dup = duplicate_key(text) ->
        {key, line} = dup
        {:error, [%{message: "duplicate key \"#{key}\"", line: line, column: nil}]}

      true ->
        do_parse(text)
    end
  end

  defp do_parse(text) do
    Application.ensure_all_started(:yamerl)

    case :yamerl_constr.string(String.to_charlist(text), [:detailed_constr, {:schema, :core}]) do
      [] ->
        {:error, [%{message: "document is empty", line: 1, column: 1}]}

      [doc] ->
        root = elem(doc, 1)

        try do
          {value, _count} = convert(root, 0, 0)
          {:ok, value}
        catch
          {:yaml_error, message, pres} -> {:error, [%{message: message, line: pres[:line], column: pres[:column]}]}
        end

      _many ->
        {:error, [%{message: "only one YAML document per file is supported", line: nil, column: nil}]}
    end
  catch
    {:yamerl_exception, errors} ->
      {:error,
       Enum.map(errors, fn
         {:yamerl_parsing_error, _, msg, line, col, _, _, _} -> %{message: to_string(msg), line: line, column: col}
         other -> %{message: inspect(other), line: nil, column: nil}
       end)}
  end

  defp anchor_line(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(fn {line, n} ->
      stripped = strip_quoted(line)
      if Regex.match?(~r/(^|[\s\[\{,:-])[&*][A-Za-z0-9_-]+|<<\s*:/, stripped) and not comment_only?(stripped), do: n
    end)
  end

  defp strip_quoted(line) do
    line
    |> String.replace(~r/"(\\.|[^"\\])*"/, "\"\"")
    |> String.replace(~r/'[^']*'/, "''")
    |> String.replace(~r/\s#.*$/, "")
  end

  def duplicate_key(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce_while({[], nil}, fn {raw, n}, {stack, block} ->
      line = raw
      indent = String.length(raw) - String.length(String.trim_leading(raw))
      trimmed = String.trim(line)

      cond do
        block && (trimmed == "" or indent > block) ->
          {:cont, {stack, block}}

        trimmed == "" or String.starts_with?(trimmed, "#") or trimmed == "---" ->
          {:cont, {stack, nil}}

        true ->
          {item?, rest, key_indent} =
            case Regex.run(~r/^(\s*)-\s+(.*)$/, raw) do
              [_, sp, rest] -> {true, rest, String.length(sp) + 2}
              nil -> {false, String.trim_leading(raw), indent}
            end

          case Regex.run(~r/^("(?:[^"\\]|\\.)*"|'[^']*'|[^\s#:\-\[\{][^:#]*?|-[^\s:#][^:#]*?)\s*:(\s|$)(.*)$/, rest) do
            [_, key, _, value] ->
              key = key |> String.trim() |> String.trim("\"") |> String.trim("'")
              stack = Enum.drop_while(stack, fn {i, _} -> i > key_indent or (item? and i >= key_indent) end)

              {stack, dup} =
                case stack do
                  [{^key_indent, keys} | tail] when not item? ->
                    {[{key_indent, MapSet.put(keys, key)} | tail], MapSet.member?(keys, key)}

                  _ ->
                    {[{key_indent, MapSet.new([key])} | stack], false}
                end

              block_next = if Regex.match?(~r/^[|>][0-9+-]*\s*(#.*)?$/, String.trim(value)), do: key_indent, else: nil
              if dup, do: {:halt, {key, n}}, else: {:cont, {stack, block_next}}

            nil ->
              {:cont, {stack, nil}}
          end
      end
    end)
    |> case do
      {key, n} when is_binary(key) -> {key, n}
      _ -> nil
    end
  end

  defp comment_only?(line), do: String.trim_leading(line) |> String.starts_with?("#")

  defp convert(_node, depth, _count) when depth > @max_depth,
    do: throw({:yaml_error, "document is nested too deeply", []})

  defp convert(_node, _depth, count) when count > @max_nodes,
    do: throw({:yaml_error, "document has too many nodes", []})

  defp convert({:yamerl_map, _, _tag, pres, pairs}, depth, count) do
    Enum.reduce(pairs, {%{}, count + 1}, fn {k, v}, {acc, c} ->
      {key, c} = convert(k, depth + 1, c)

      unless is_binary(key) or is_number(key) or is_boolean(key),
        do: throw({:yaml_error, "mapping keys must be scalars", pres})

      key = to_string(key)
      if Map.has_key?(acc, key), do: throw({:yaml_error, "duplicate key \"#{key}\"", elem(k, 3)})
      {value, c} = convert(v, depth + 1, c)
      {Map.put(acc, key, value), c}
    end)
  end

  defp convert({:yamerl_seq, _, _tag, _pres, items, _n}, depth, count) do
    {list, c} =
      Enum.reduce(items, {[], count + 1}, fn item, {acc, c} ->
        {v, c} = convert(item, depth + 1, c)
        {[v | acc], c}
      end)

    {Enum.reverse(list), c}
  end

  defp convert({:yamerl_str, _, _, _, value}, _d, c), do: {:unicode.characters_to_binary(value), c + 1}
  defp convert({:yamerl_int, _, _, _, value}, _d, c), do: {value, c + 1}
  defp convert({:yamerl_float, _, _, _, value}, _d, c), do: {value, c + 1}
  defp convert({:yamerl_bool, _, _, _, value}, _d, c), do: {value, c + 1}
  defp convert({:yamerl_null, _, _, _}, _d, c), do: {nil, c + 1}
  defp convert(other, _d, _c), do: throw({:yaml_error, "unsupported YAML construct", elem(other, 3)})

  @key_order ~w(apiVersion kind metadata spec name labels description)

  def encode(term), do: emit(term, 0) |> IO.iodata_to_binary()

  defp emit(map, indent) when is_map(map) and map_size(map) == 0, do: [pad(indent), "{}\n"]

  defp emit(map, indent) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _} -> {Enum.find_index(@key_order, &(&1 == k)) || 999, k} end)
    |> Enum.map(fn {k, v} -> [pad(indent), key(k), ":", value_suffix(v, indent)] end)
  end

  defp emit(list, indent) when is_list(list) do
    Enum.map(list, fn
      item when is_map(item) and map_size(item) > 0 ->
        [first | rest] = emit(item, indent + 2)
        [pad(indent), "- ", String.trim_leading(IO.iodata_to_binary(first)) | rest]

      item when is_list(item) and item != [] ->
        [pad(indent), "-\n", emit(item, indent + 2)]

      item ->
        [pad(indent), "- ", scalar(item), "\n"]
    end)
  end

  defp value_suffix(v, _indent) when is_map(v) and map_size(v) == 0, do: " {}\n"
  defp value_suffix([], _indent), do: " []\n"
  defp value_suffix(v, indent) when is_map(v), do: ["\n", emit(v, indent + 2)]
  defp value_suffix(v, indent) when is_list(v), do: ["\n", emit(v, indent + 2)]
  defp value_suffix(v, _indent), do: [" ", scalar(v), "\n"]

  defp pad(n), do: String.duplicate(" ", n)

  defp key(k) do
    k = to_string(k)

    plain =
      Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_.\/-]*$/, k) and
        not Regex.match?(~r/^(true|false|null|yes|no|on|off|y|n|~)$/i, k)

    if plain, do: k, else: Jason.encode!(k)
  end

  defp scalar(nil), do: "null"
  defp scalar(true), do: "true"
  defp scalar(false), do: "false"
  defp scalar(n) when is_integer(n), do: Integer.to_string(n)
  defp scalar(n) when is_float(n), do: Float.to_string(n)

  defp scalar(s) when is_binary(s) do
    plain =
      Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9 _.\/:@+-]*$/, s) and
        not Regex.match?(~r/^(true|false|yes|no|on|off|null|~|y|n)$/i, s) and
        not Regex.match?(~r/^[-+]?(\d[\d_]*(\.\d*)?([eE][-+]?\d+)?|0x[0-9a-fA-F]+|0o[0-7]+|\.inf|\.nan)$/i, s) and
        not String.contains?(s, ": ") and not String.ends_with?(s, ":") and not String.ends_with?(s, " ")

    if plain, do: s, else: Jason.encode!(s)
  end

  defp scalar(other), do: Jason.encode!(other)
end
