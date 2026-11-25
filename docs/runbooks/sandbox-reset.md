# Runbook: sandbox reset

Resetting deletes **all** sandbox data: the SatOps database, the demo fintech database and the regtest chains.

```bash
make reset-sandbox
```

The script refuses to run unless the Compose project is `satops`, refuses configurations that mention mainnet,
asks you to type the project name, and only removes this project's containers and volumes. Other containers on
the host are never touched.

After a reset: `make up`, then `make admin EMAIL=you@example.com`. Bootstrap resources and bundled scenarios
are applied again on first boot.

On Kubernetes, uninstall the release and delete the sandbox namespace and PVCs explicitly
(`kubectl delete ns sandbox-default`); persistent volumes are never deleted implicitly.
