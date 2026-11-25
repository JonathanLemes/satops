defmodule SatOpsWeb.ImportController do
  use SatOpsWeb, :controller
  alias SatOps.{Audit, Integrations}

  @max_rows 10_000
  @columns ~w(source_record_id kind account_ref amount_sats txid vout status occurred_at)

  def csv(conn, %{"integration_id" => id, "file" => %Plug.Upload{path: path}}) do
    with %{} = integration <- Integrations.get(id),
         :ok <- authorize(conn, :"integration.manage", integration.environment_id),
         true <- integration.kind == "csv_import" || {:error, "integration is not a CSV import"},
         %{size: size} when size <= 1_000_000 <- File.stat!(path) || :too_large,
         {:ok, records} <- parse(File.read!(path)) do
      count = Integrations.store_records(integration, records, "csv")

      Audit.record!(conn.assigns.current_user, "integration.csv_imported",
        resource: integration,
        changes: %{rows: count}
      )

      json(conn, %{imported: count})
    else
      nil -> error(conn, 404, "not_found")
      {:error, %Plug.Conn{} = halted} -> halted
      {:error, msg} when is_binary(msg) -> error(conn, 422, "invalid_csv", msg)
      _ -> error(conn, 413, "file_too_large", "CSV files are limited to 1 MB")
    end
  end

  def csv(conn, _), do: error(conn, 400, "bad_request", "multipart field file is required")

  def parse(text) do
    rows = text |> String.replace("\r\n", "\n") |> String.split("\n", trim: true) |> Enum.map(&parse_line/1)

    case rows do
      [] ->
        {:error, "empty file"}

      [header | data] ->
        header = Enum.map(header, &String.trim/1)

        cond do
          length(data) > @max_rows ->
            {:error, "at most #{@max_rows} rows are accepted"}

          Enum.any?(["source_record_id", "amount_sats"], &(&1 not in header)) ->
            {:error, "header must include #{Enum.join(@columns, ",")}"}

          true ->
            convert(header, data)
        end
    end
  end

  defp convert(header, data) do
    data
    |> Enum.with_index(2)
    |> Enum.reduce_while({:ok, []}, fn {row, line}, {:ok, acc} ->
      map = Enum.zip(header, row) |> Map.new() |> Map.take(@columns)

      case Integer.parse(map["amount_sats"] || "") do
        {amount, ""} when amount >= 0 ->
          vout = if map["vout"] in [nil, ""], do: nil, else: String.to_integer(map["vout"])
          rec = map |> Map.put("amount_sats", amount) |> Map.put("vout", vout) |> Map.update("txid", nil, &blank/1)
          {:cont, {:ok, [rec | acc]}}

        _ ->
          {:halt, {:error, "line #{line}: amount_sats must be a non-negative integer number of satoshis"}}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  rescue
    ArgumentError -> {:error, "vout must be an integer"}
  end

  defp blank(""), do: nil
  defp blank(v), do: v

  def parse_line(line), do: do_parse(String.graphemes(line), "", [], false)

  defp do_parse([], cur, acc, _q), do: Enum.reverse([cur | acc])
  defp do_parse(["\"", "\"" | rest], cur, acc, true), do: do_parse(rest, cur <> "\"", acc, true)
  defp do_parse(["\"" | rest], cur, acc, q), do: do_parse(rest, cur, acc, not q)
  defp do_parse(["," | rest], cur, acc, false), do: do_parse(rest, "", [cur | acc], false)
  defp do_parse([c | rest], cur, acc, q), do: do_parse(rest, cur <> c, acc, q)
end
