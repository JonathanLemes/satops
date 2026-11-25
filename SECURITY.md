# Security policy

SatOps is a sandbox. It is designed to run only with Bitcoin Core in regtest mode and synthetic data.
Do not point it at mainnet nodes and never store real credentials, seed phrases or private keys in it.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub Security Advisories on this repository. Include the
affected version, a description of the impact and the minimal steps to reproduce. Do not open a public issue
for unpatched vulnerabilities. You can expect an acknowledgement within seven days.

## Supported versions

Only the latest release on the `main` branch receives security fixes while the project is pre 1.0.

## Built-in protections

- Argon2 password hashing, HttpOnly SameSite=Strict session cookies, CSRF tokens on every mutation.
- Rate limiting on login and webhook endpoints.
- Role and environment scoped authorization on every GraphQL field.
- Secrets encrypted at rest with AES-256-GCM and referenced by name from configuration; they are never
  exported in YAML, reports or logs.
- SSRF protection: integrations may only reach allowlisted hosts and never link-local or metadata addresses;
  redirects are not followed.
- Webhook HMAC signatures with timestamp tolerance and delivery deduplication.
- Regtest enforcement in the database schema, the configuration schema and at connection time.
- Append-only audit log enforced by a database trigger. It is not cryptographically tamper evident.

See [docs/threat-model.md](docs/threat-model.md) for trust boundaries and known limitations.
