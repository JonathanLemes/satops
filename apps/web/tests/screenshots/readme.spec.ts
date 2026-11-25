import { expect, test, type Page } from "@playwright/test";
import { login } from "../e2e/helpers";

const OUT = "../../docs/screenshots";

async function graphql<T>(page: Page, query: string, variables: Record<string, unknown> = {}): Promise<T> {
  return page.evaluate(
    async ({ query, variables }) => {
      const me = await (await fetch("/api/auth/me")).json();
      const res = await fetch("/graphql", {
        method: "POST",
        headers: { "content-type": "application/json", "x-csrf-token": me.csrfToken },
        body: JSON.stringify({ query, variables: { ...variables, e: me.environments[0].id } }),
      });
      return (await res.json()).data;
    },
    { query, variables },
  );
}

async function settle(page: Page) {
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(1200);
}

async function shot(page: Page, name: string, path?: string) {
  if (path) await page.goto(path);
  await settle(page);
  await page.mouse.move(0, 0);
  await page.screenshot({ path: `${OUT}/${name}.png` });
}

test("README screenshots", async ({ page }) => {
  await login(page);

  await shot(page, "customer-overview", "/");
  await shot(page, "engineering-overview", "/engineering");

  const tx = await graphql<{ transactions: { nodes: { txid: string }[] } }>(
    page,
    "query($e: ID!){ transactions(environmentId: $e, filter: {watchedOnly: true}, first: 40){ nodes { txid } } }",
  );
  await shot(page, "transactions", "/transactions");
  await page.goto(`/transactions/${tx.transactions.nodes[0]!.txid}`);
  await shot(page, "transaction-detail");

  await shot(page, "wallets", "/wallets");

  const runs = await graphql<{ reconciliationRuns: { id: string; status: string }[] }>(
    page,
    "query($e: ID!){ reconciliationRuns(environmentId: $e, limit: 20){ id status } }",
  );
  await shot(page, "discrepancies", "/reconciliation");
  const completed = runs.reconciliationRuns.find((r) => r.status === "completed")!;
  await shot(page, "reconciliation-run", `/reconciliation/runs/${completed.id}`);

  const disc = await graphql<{ discrepancies: { id: string; kind: string }[] }>(
    page,
    "query($e: ID!){ discrepancies(environmentId: $e, limit: 50){ id kind } }",
  );
  const duplicate = disc.discrepancies.find((d) => d.kind === "duplicate_credit") ?? disc.discrepancies[0]!;
  await shot(page, "discrepancy-detail", `/reconciliation/discrepancies/${duplicate.id}`);

  const ops = await graphql<{ ledgerOperations: { operationId: string; generation: number }[] }>(
    page,
    'query($e: ID!){ ledgerOperations(environmentId: $e, kind: "deposit", limit: 200){ operationId generation } }',
  );
  const reorged = ops.ledgerOperations.find((o) => o.generation > 0) ?? ops.ledgerOperations[0]!;
  await shot(page, "financial-timeline", `/audit?operation=${encodeURIComponent(reorged.operationId)}`);

  await shot(page, "nodes", "/engineering/nodes");
  await page.goto("/engineering/blockchain");
  await settle(page);
  await page.getByRole("tab", { name: "Reorganizations" }).click();
  await shot(page, "blockchain-reorganizations");

  await page.goto("/engineering/ledger");
  await settle(page);
  await page.getByRole("tab", { name: "Journals" }).click();
  await shot(page, "ledger-journals");

  const exp = await graphql<{ experimentRuns: { id: string; scenarioName: string; status: string }[] }>(
    page,
    "query($e: ID!){ experimentRuns(environmentId: $e, limit: 100){ id scenarioName status } }",
  );
  await shot(page, "experiments", "/engineering/experiments");
  const reorgRun = exp.experimentRuns.find(
    (r) => r.scenarioName === "blockchain-reorganization" && r.status === "passed",
  )!;
  await shot(page, "experiment-run", `/engineering/experiments/runs/${reorgRun.id}`);

  await shot(page, "configuration-form", "/engineering/configuration/BitcoinIntegration/bitcoin-0");
  await page.getByRole("tab", { name: "YAML" }).click();
  await expect(page.locator(".monaco-editor")).toBeVisible();
  await shot(page, "configuration-yaml");
  await page.goto("/engineering/configuration/Environment/default-sandbox");
  await settle(page);
  await page.getByRole("spinbutton", { name: /Required Confirmations/ }).fill("6");
  await page.getByRole("button", { name: "Review plan" }).click();
  await expect(page.getByText("Impact")).toBeVisible();
  await page.getByText("Impact").scrollIntoViewIfNeeded();
  await shot(page, "configuration-plan");

  await shot(page, "integrations", "/engineering/integrations");

  await page.emulateMedia({ colorScheme: "dark" });
  await page.evaluate(() => localStorage.setItem("satops.theme", "dark"));
  await shot(page, "engineering-overview-dark", "/engineering");
  await page.evaluate(() => localStorage.setItem("satops.theme", "light"));

  await page.evaluate(() => localStorage.setItem("satops.locale", "pt-BR"));
  await shot(page, "customer-overview-pt-br", "/");
  await page.evaluate(() => localStorage.setItem("satops.locale", "en"));
});

test("login screenshot", async ({ page }) => {
  await page.goto("/login");
  await page.evaluate(() => localStorage.setItem("satops.locale", "en"));
  await page.reload();
  await shot(page, "login");
});
