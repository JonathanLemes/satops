defmodule SatOps.Repo.Migrations.CreateLedger do
  use Ecto.Migration

  def up do
    create table(:ledger_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :restrict),
        null: false

      add :code, :text, null: false
      add :name, :text, null: false
      add :type, :text, null: false
      add :normal_balance, :text, null: false
      add :asset, :text, null: false, default: "BTC"
      add :restricted, :boolean, null: false, default: false
      add :owner_ref, :text
      timestamps()
    end

    create unique_index(:ledger_accounts, [:environment_id, :code, :asset])
    create unique_index(:ledger_accounts, [:id, :environment_id, :asset])

    create constraint(:ledger_accounts, :ledger_accounts_type_check,
             check: "type IN ('asset','liability','equity','revenue','expense')"
           )

    create constraint(:ledger_accounts, :ledger_accounts_normal_check,
             check: "normal_balance IN ('debit','credit')"
           )

    create constraint(:ledger_accounts, :ledger_accounts_asset_check,
             check: "asset ~ '^[A-Z0-9]{2,12}$'"
           )

    create table(:ledger_journals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :restrict),
        null: false

      add :operation_id, :text, null: false
      add :entry_kind, :text, null: false
      add :rule_name, :text, null: false
      add :rule_version, :integer, null: false
      add :description, :text
      add :reverses_journal_id, :binary_id
      add :correlation_id, :binary_id
      add :causation_id, :binary_id
      add :actor_id, :binary_id
      add :metadata, :map, null: false, default: %{}
      add :posted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:ledger_journals, [:environment_id, :operation_id, :entry_kind])
    create unique_index(:ledger_journals, [:id, :environment_id])

    create unique_index(:ledger_journals, [:reverses_journal_id],
             where: "reverses_journal_id IS NOT NULL"
           )

    create index(:ledger_journals, [:environment_id, :posted_at])
    create index(:ledger_journals, [:correlation_id])

    execute """
    ALTER TABLE ledger_journals ADD CONSTRAINT ledger_journals_reverses_fk
    FOREIGN KEY (reverses_journal_id, environment_id) REFERENCES ledger_journals (id, environment_id)
    """

    create table(:ledger_postings) do
      add :journal_id, :binary_id, null: false
      add :environment_id, :binary_id, null: false
      add :account_id, :binary_id, null: false
      add :asset, :text, null: false
      add :direction, :text, null: false
      add :amount_sats, :bigint, null: false
      add :posted_at, :utc_datetime_usec, null: false
    end

    execute """
    ALTER TABLE ledger_postings
      ADD CONSTRAINT ledger_postings_journal_fk FOREIGN KEY (journal_id, environment_id)
        REFERENCES ledger_journals (id, environment_id),
      ADD CONSTRAINT ledger_postings_account_fk FOREIGN KEY (account_id, environment_id, asset)
        REFERENCES ledger_accounts (id, environment_id, asset)
    """

    create index(:ledger_postings, [:journal_id])
    create index(:ledger_postings, [:account_id, :id])

    create constraint(:ledger_postings, :ledger_postings_direction_check,
             check: "direction IN ('debit','credit')"
           )

    create constraint(:ledger_postings, :ledger_postings_amount_check, check: "amount_sats > 0")

    create table(:ledger_balances, primary_key: false) do
      add :account_id, references(:ledger_accounts, type: :binary_id, on_delete: :restrict),
        primary_key: true

      add :environment_id, :binary_id, null: false
      add :asset, :text, null: false
      add :normal_balance, :text, null: false
      add :restricted, :boolean, null: false
      add :debit_total, :bigint, null: false, default: 0
      add :credit_total, :bigint, null: false, default: 0
      add :balance, :bigint, null: false, default: 0
      add :version, :bigint, null: false, default: 0
      add :updated_at, :utc_datetime_usec, null: false
    end

    create constraint(:ledger_balances, :ledger_balances_restricted_non_negative,
             check: "NOT restricted OR balance >= 0"
           )

    create constraint(:ledger_balances, :ledger_balances_totals_check,
             check: "debit_total >= 0 AND credit_total >= 0"
           )

    create constraint(:ledger_balances, :ledger_balances_consistent,
             check:
               "balance = CASE WHEN normal_balance = 'debit' THEN debit_total - credit_total ELSE credit_total - debit_total END"
           )

    create table(:ledger_idempotency, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :restrict),
        null: false

      add :scope, :text, null: false
      add :key, :text, null: false
      add :fingerprint, :text, null: false
      add :journal_id, :binary_id
      add :result, :map, null: false, default: %{}
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:ledger_idempotency, [:environment_id, :scope, :key])

    create table(:ledger_operations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :environment_id, references(:environments, type: :binary_id, on_delete: :restrict),
        null: false

      add :operation_id, :text, null: false
      add :kind, :text, null: false
      add :state, :text, null: false
      add :account_ref, :text
      add :counterparty_ref, :text
      add :asset, :text, null: false, default: "BTC"
      add :amount_sats, :bigint, null: false
      add :fee_sats, :bigint, null: false, default: 0
      add :txid, :text
      add :vout, :integer
      add :block_hash, :text
      add :generation, :integer, null: false, default: 0
      add :correlation_id, :binary_id
      add :metadata, :map, null: false, default: %{}
      add :lock_version, :integer, null: false, default: 1
      timestamps()
    end

    create unique_index(:ledger_operations, [:environment_id, :operation_id])
    create index(:ledger_operations, [:environment_id, :txid, :vout])
    create index(:ledger_operations, [:environment_id, :state])

    create constraint(:ledger_operations, :ledger_operations_amount_check,
             check: "amount_sats > 0 AND fee_sats >= 0"
           )

    execute """
    CREATE FUNCTION ledger_posting_apply() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      acct ledger_accounts%ROWTYPE;
    BEGIN
      SELECT * INTO acct FROM ledger_accounts WHERE id = NEW.account_id;
      INSERT INTO ledger_balances (account_id, environment_id, asset, normal_balance, restricted, updated_at)
      VALUES (acct.id, acct.environment_id, acct.asset, acct.normal_balance, acct.restricted, now())
      ON CONFLICT (account_id) DO NOTHING;

      UPDATE ledger_balances b SET
        debit_total = b.debit_total + CASE WHEN NEW.direction = 'debit' THEN NEW.amount_sats ELSE 0 END,
        credit_total = b.credit_total + CASE WHEN NEW.direction = 'credit' THEN NEW.amount_sats ELSE 0 END,
        balance = b.balance + CASE
          WHEN (NEW.direction = b.normal_balance) THEN NEW.amount_sats
          ELSE -NEW.amount_sats END,
        version = b.version + 1,
        updated_at = now()
      WHERE b.account_id = NEW.account_id;
      RETURN NULL;
    END $$;
    """

    execute """
    CREATE TRIGGER ledger_postings_apply AFTER INSERT ON ledger_postings
    FOR EACH ROW EXECUTE FUNCTION ledger_posting_apply()
    """

    execute """
    CREATE FUNCTION ledger_journal_check_balanced() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      jid uuid;
      bad record;
      n integer;
    BEGIN
      jid := CASE WHEN TG_TABLE_NAME = 'ledger_journals' THEN NEW.id ELSE NEW.journal_id END;
      SELECT count(*) INTO n FROM ledger_postings WHERE journal_id = jid;
      IF n < 2 THEN
        RAISE EXCEPTION 'journal % must have at least two postings', jid USING ERRCODE = 'check_violation';
      END IF;
      SELECT asset,
             sum(CASE WHEN direction = 'debit' THEN amount_sats ELSE 0 END) AS debits,
             sum(CASE WHEN direction = 'credit' THEN amount_sats ELSE 0 END) AS credits
        INTO bad
        FROM ledger_postings WHERE journal_id = jid
        GROUP BY asset
        HAVING sum(CASE WHEN direction = 'debit' THEN amount_sats ELSE 0 END)
            <> sum(CASE WHEN direction = 'credit' THEN amount_sats ELSE 0 END)
        LIMIT 1;
      IF FOUND THEN
        RAISE EXCEPTION 'journal % is unbalanced for asset %: debits % credits %', jid, bad.asset, bad.debits, bad.credits
          USING ERRCODE = 'check_violation';
      END IF;
      RETURN NULL;
    END $$;
    """

    execute """
    CREATE CONSTRAINT TRIGGER ledger_postings_balanced AFTER INSERT ON ledger_postings
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION ledger_journal_check_balanced()
    """

    execute """
    CREATE CONSTRAINT TRIGGER ledger_journals_have_postings AFTER INSERT ON ledger_journals
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION ledger_journal_check_balanced()
    """

    execute """
    CREATE TRIGGER ledger_journals_immutable BEFORE UPDATE OR DELETE ON ledger_journals
    FOR EACH ROW EXECUTE FUNCTION satops_forbid_mutation()
    """

    execute """
    CREATE TRIGGER ledger_postings_immutable BEFORE UPDATE OR DELETE ON ledger_postings
    FOR EACH ROW EXECUTE FUNCTION satops_forbid_mutation()
    """

    execute """
    CREATE FUNCTION ledger_balances_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF pg_trigger_depth() < 2 THEN
        RAISE EXCEPTION 'ledger_balances is maintained by postings only' USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER ledger_balances_guard BEFORE INSERT OR UPDATE OR DELETE ON ledger_balances
    FOR EACH ROW EXECUTE FUNCTION ledger_balances_guard()
    """
  end

  def down do
    drop table(:ledger_operations)
    drop table(:ledger_idempotency)
    drop table(:ledger_balances)
    drop table(:ledger_postings)
    drop table(:ledger_journals)
    drop table(:ledger_accounts)
    execute "DROP FUNCTION ledger_balances_guard()"
    execute "DROP FUNCTION ledger_journal_check_balanced()"
    execute "DROP FUNCTION ledger_posting_apply()"
  end
end
