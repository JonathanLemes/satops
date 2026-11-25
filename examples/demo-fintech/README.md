# Demo Fintech

A deliberately small, independent "financial institution" used only to exercise SatOps.
It runs on Bitcoin Core **regtest** with synthetic customers and fake money.

It has its own database, credentials, ledger implementation and API. SatOps integrates with it
only through the HTTP contract below and signed webhooks, never through its tables. The two
ledgers are implemented independently on purpose: reconciliation can only detect real defects
when the systems being compared do not share code.

## API (Bearer token)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Node and fault summary (no auth) |
| GET/POST | `/v1/customers` | List or create synthetic customers |
| POST | `/v1/customers/:id/deposit-addresses` | New regtest deposit address |
| GET | `/v1/deposit-addresses` | Address to customer mapping |
| GET | `/v1/records` | Deposits, withdrawals and transfers |
| GET | `/v1/balances` | Available, pending and reserved balances |
| POST | `/v1/withdrawals` | Withdrawal with idempotency key |
| POST | `/v1/transfers` | Internal transfer with idempotency key |
| GET/POST | `/v1/faults` | Simulated fault modes |
| POST | `/v1/test/webhooks/flush` | Deliver pending webhooks now |
| POST | `/v1/test/webhooks/redeliver` | Re-send delivered webhooks (retry and reordering tests) |

Webhooks carry `x-demofintech-signature: t=<unix>,v1=<hex hmac-sha256 of "t.body">` and a
`x-demofintech-delivery` id.

## Fault modes (simulations, disabled by default)

`duplicate_deposit_credit`, `missing_deposit_credit`, `incorrect_amount`, `delayed_settlement`,
`ignore_reorg`, `duplicate_webhook_processing`, `invalid_balance_projection`,
`temporary_api_outage`, `timeout_after_success`, `delay_response`.

They exist only so SatOps can prove it detects incorrect financial applications. They can be
enabled only when `FAULT_MODES_ALLOWED=true`, and every change is logged as a simulated fault.
