defmodule SatOps.Secrets do
  import Ecto.Query
  alias SatOps.Repo

  defmodule Secret do
    use SatOps.Schema

    schema "secrets" do
      field :environment_id, :binary_id
      field :name, :string
      field :ciphertext, :binary
      timestamps()
    end
  end

  @aad "satops.secret.v1"

  def put(environment_id, name, value) when is_binary(value) do
    upsert(environment_id, name, value)
    :ok
  end

  def fetch(environment_id, name) do
    query =
      from s in Secret,
        where: s.name == ^name and (s.environment_id == ^environment_id or is_nil(s.environment_id)),
        order_by: [desc_nulls_last: s.environment_id],
        limit: 1

    case Repo.one(query) do
      nil -> {:error, :secret_not_found}
      secret -> decrypt(secret.ciphertext)
    end
  end

  def names(environment_id) do
    Repo.all(
      from s in Secret,
        where: s.environment_id == ^environment_id or is_nil(s.environment_id),
        select: s.name,
        distinct: true,
        order_by: s.name
    )
  end

  def encrypt(plaintext) do
    iv = :crypto.strong_rand_bytes(12)
    {ct, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, plaintext, @aad, true)
    <<1, iv::binary-12, tag::binary-16, ct::binary>>
  end

  def decrypt(<<1, iv::binary-12, tag::binary-16, ct::binary>>) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, ct, @aad, tag, false) do
      :error -> {:error, :decryption_failed}
      plaintext -> {:ok, plaintext}
    end
  end

  def decrypt(_), do: {:error, :decryption_failed}

  defp key do
    raw = Application.fetch_env!(:sat_ops, :secret_key)

    case Base.decode64(raw) do
      {:ok, <<key::binary-32>>} -> key
      _ -> :crypto.hash(:sha256, raw)
    end
  end

  def bootstrap_from_env do
    Application.get_env(:sat_ops, :bootstrap_secrets, "")
    |> String.split(";", trim: true)
    |> Enum.each(fn pair ->
      case String.split(pair, "=", parts: 2) do
        [name, value] when value != "" -> put_global(String.trim(name), value)
        _ -> :ok
      end
    end)
  end

  defp put_global(name, value), do: upsert(nil, name, value)

  defp upsert(environment_id, name, value) do
    ciphertext = encrypt(value)
    now = DateTime.utc_now()

    query =
      if environment_id,
        do: from(s in Secret, where: s.name == ^name and s.environment_id == ^environment_id),
        else: from(s in Secret, where: s.name == ^name and is_nil(s.environment_id))

    case Repo.one(query) do
      nil ->
        Repo.insert!(%Secret{
          environment_id: environment_id,
          name: name,
          ciphertext: ciphertext,
          inserted_at: now,
          updated_at: now
        })

      secret ->
        secret |> Ecto.Changeset.change(ciphertext: ciphertext, updated_at: now) |> Repo.update!()
    end
  end
end
