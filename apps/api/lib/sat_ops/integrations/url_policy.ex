defmodule SatOps.Integrations.UrlPolicy do
  import Bitwise

  @blocked_v4 [
    {{0, 0, 0, 0}, 8},
    {{169, 254, 0, 0}, 16},
    {{100, 100, 100, 200}, 32},
    {{224, 0, 0, 0}, 4},
    {{255, 255, 255, 255}, 32}
  ]

  def validate_url(url, opts \\ []) when is_binary(url) do
    with %URI{scheme: scheme, host: host} = uri
         when scheme in ["http", "https", "tcp"] and is_binary(host) and host != "" <-
           URI.parse(url),
         :ok <- validate_host(host, opts) do
      {:ok, uri}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "invalid URL: only http, https and tcp URLs with a host are accepted"}
    end
  end

  def validate_host(host, opts \\ []) do
    allowed =
      Keyword.get_lazy(opts, :allowed_hosts, fn -> Application.get_env(:sat_ops, :allowed_integration_hosts, []) end)

    resolver = Keyword.get(opts, :resolver, &resolve/1)
    host = String.downcase(host)

    cond do
      host not in allowed ->
        {:error, "host #{host} is not in the sandbox allowlist (SATOPS_ALLOWED_INTEGRATION_HOSTS)"}

      true ->
        case resolver.(host) do
          {:ok, ips} ->
            case Enum.find(ips, &blocked_ip?/1) do
              nil -> :ok
              ip -> {:error, "host #{host} resolves to a forbidden address #{:inet.ntoa(ip)}"}
            end

          {:error, _} ->
            {:error, "host #{host} could not be resolved"}
        end
    end
  end

  def resolve(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ip} ->
        {:ok, [ip]}

      _ ->
        v4 =
          case :inet.getaddrs(String.to_charlist(host), :inet),
            do: (
              {:ok, l} -> l
              _ -> []
            )

        v6 =
          case :inet.getaddrs(String.to_charlist(host), :inet6),
            do: (
              {:ok, l} -> l
              _ -> []
            )

        if v4 ++ v6 == [], do: {:error, :nxdomain}, else: {:ok, v4 ++ v6}
    end
  end

  def blocked_ip?({_, _, _, _} = ip), do: Enum.any?(@blocked_v4, fn {net, bits} -> in_cidr?(ip, net, bits) end)
  def blocked_ip?({0, 0, 0, 0, 0, 0xFFFF, a, b}), do: blocked_ip?({a >>> 8, a &&& 255, b >>> 8, b &&& 255})
  def blocked_ip?({0xFE80, _, _, _, _, _, _, _}), do: true
  def blocked_ip?({0xFD00, 0xEC2, 0, 0, 0, 0, 0, 0x254}), do: true
  def blocked_ip?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  def blocked_ip?(_), do: false

  defp in_cidr?(ip, net, bits) do
    mask = bnot((1 <<< (32 - bits)) - 1) &&& 0xFFFFFFFF
    (to_int(ip) &&& mask) == (to_int(net) &&& mask)
  end

  defp to_int({a, b, c, d}), do: (a <<< 24) + (b <<< 16) + (c <<< 8) + d
end
