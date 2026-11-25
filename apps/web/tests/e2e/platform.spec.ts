import { expect, test } from "@playwright/test";
import { ADMIN, login, unique } from "./helpers";

test("rejects wrong credentials and signs in", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill(ADMIN.email);
  await page.getByLabel("Password").fill("definitely-wrong-password");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("alert")).toContainText("Invalid email or password");
  await login(page);
});

test("switches the interface to Brazilian Portuguese", async ({ page }) => {
  await login(page);
  await page.getByRole("button", { name: "Language" }).click();
  await page.getByRole("menuitem", { name: "Português (Brasil)" }).click();
  await expect(page.getByRole("heading", { name: "Visão financeira" })).toBeVisible();
  await page.getByRole("button", { name: "Idioma" }).click();
  await page.getByRole("menuitem", { name: "English" }).click();
});

test("creates an environment through the form, reviews the plan and applies it", async ({ page }) => {
  await login(page);
  const name = unique("e2e-env");
  await page.goto("/engineering/configuration/new?kind=Environment");
  await page.getByLabel("metadata.name").fill(name);
  await page.getByRole("tab", { name: "YAML" }).click();
  await expect(page.locator(".monaco-editor")).toContainText(name);
  await page.getByRole("tab", { name: "Form" }).click();
  await page.getByRole("button", { name: "Review plan" }).click();
  await expect(page.getByText("Creates sandbox environment")).toBeVisible();
  await page.getByRole("button", { name: "Apply" }).click();
  await expect(page.getByText("Configuration applied")).toBeVisible();
  await page.goto("/engineering/configuration?kind=Environment");
  await expect(page.getByRole("cell", { name })).toBeVisible();
});

test("backend rejects duplicate YAML keys with the line number", async ({ page }) => {
  await login(page);
  await page.goto("/engineering/configuration/Environment/default-sandbox");
  await page.getByRole("tab", { name: "YAML" }).click();
  const editor = page.locator(".monaco-editor").first();
  await editor.click();
  await page.keyboard.press("ControlOrMeta+End");
  await page.keyboard.type("\nkind: Environment");
  await page.getByRole("button", { name: "Validate" }).click();
  await expect(page.getByText(/duplicate|Map keys must be unique/i).first()).toBeVisible();
});

test("tests the Bitcoin Core connection", async ({ page }) => {
  await login(page);
  await page.goto("/engineering/integrations");
  await page
    .getByRole("row", { name: /bitcoin-0/ })
    .getByRole("button", { name: "Test connection" })
    .click();
  await expect(page.getByText("Connection healthy")).toBeVisible();
});

test("runs a reconciliation and opens the run", async ({ page }) => {
  await login(page);
  await page.goto("/reconciliation");
  await page.getByRole("button", { name: "Run reconciliation" }).click();
  await expect(page).toHaveURL(/reconciliation\/runs\//);
  await expect(page.getByText("Sources")).toBeVisible();
  await expect(page.getByRole("cell", { name: /native-ledger/ }).first()).toBeVisible({ timeout: 60_000 });
});

test("customizes the engineering dashboard", async ({ page }) => {
  await login(page);
  await page.goto("/engineering");
  await page.getByRole("button", { name: "Customize" }).click();
  await page.getByRole("button", { name: "Add widget" }).click();
  await page.getByRole("menuitem", { name: "Block height" }).click();
  await page.getByRole("button", { name: "Done" }).click();
  await expect(page.getByText("Dashboard saved")).toBeVisible();
});

test("viewers do not see the engineering workspace", async ({ page }) => {
  await login(page);
  const email = `${unique("viewer")}@example.test`;
  await page.goto("/settings");
  await page.getByRole("button", { name: "New user" }).click();
  const sheet = page.getByRole("dialog");
  await sheet.getByLabel("Email").fill(email);
  await sheet.getByLabel("Name").fill("E2E Viewer");
  await sheet.getByLabel("Role").selectOption("viewer");
  await sheet.getByLabel("Password").fill("viewer-password-123");
  await sheet.getByRole("button", { name: "Create" }).click();
  await expect(page.getByText("User created")).toBeVisible();
  await page.getByRole("button", { name: "Account" }).click();
  await page.getByRole("menuitem", { name: "Sign out" }).click();
  await login(page, email, "viewer-password-123");
  await expect(page.getByRole("navigation", { name: "Engineering" })).toHaveCount(0);
  await page.goto("/engineering/experiments");
  await expect(page.getByRole("heading", { name: "Financial overview" })).toBeVisible();
});

test("starts an experiment and follows it to a verdict", async ({ page }) => {
  test.setTimeout(300_000);
  await login(page);
  await page.goto("/engineering/experiments");
  await page.locator("li", { hasText: "Worker crash" }).getByRole("button", { name: "Start" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Start" }).click();
  await expect(page).toHaveURL(/experiments\/runs\//);
  const header = page.locator("[data-page-header]");
  await expect(header).toContainText(/Passed|Failed|Inconclusive|Aborted/, { timeout: 240_000 });
  await expect(header).toContainText("Passed");
});
