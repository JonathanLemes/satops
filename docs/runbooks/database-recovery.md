# Runbook: database recovery

**Signals:** `/api/ready` returns 503, API errors mentioning the repo, jobs not progressing.

## Backups

```bash
docker compose exec -T postgres pg_dump -U postgres -Fc satops > satops-$(date +%F).dump
docker compose exec -T postgres pg_dump -U postgres -Fc demo_fintech > demo-fintech-$(date +%F).dump
```

Store dumps outside the host. Test restores regularly.

## Restore

1. Stop writers: `docker compose stop api demo-fintech`.
2. Restore: `docker compose exec -T postgres pg_restore -U postgres -d satops --clean --if-exists < satops-YYYY-MM-DD.dump`.
3. Start: `docker compose up -d api demo-fintech`. Migrations run first.
4. Verify: Engineering > Reference ledger shows **All invariants hold**; run a reconciliation; check that event
   consumers have no unexpected lag in Jobs and events.
5. Chain data after the dump is re-ingested from the nodes automatically (sync from the stored tip).

Ledger tables are append-only by trigger; do not disable triggers to "fix" data. Post compensating entries
instead and record the reason.
