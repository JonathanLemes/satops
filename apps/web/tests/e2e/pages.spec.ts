import { expect, test } from "@playwright/test";
import { login } from "./helpers";

for (const path of [
  "/engineering/blockchain",
  "/engineering/jobs",
  "/engineering/nodes",
  "/engineering/integrations",
  "/engineering",
  "/",
]) {
  test(`renders ${path} without API errors`, async ({ page }) => {
    const failures: string[] = [];
    page.on("response", async (res) => {
      if (res.url().includes("/graphql")) {
        if (res.status() >= 500) failures.push(`${res.status()} ${res.url()}`);
        else {
          const body = await res.json().catch(() => null);
          if (body?.errors) failures.push(JSON.stringify(body.errors).slice(0, 300));
        }
      }
    });
    await login(page);
    await page.goto(path);
    await page.waitForLoadState("networkidle");
    await expect(page.locator("main")).not.toContainText("Something went wrong");
    expect(failures).toEqual([]);
  });
}

test("realtime connection is established", async ({ page }) => {
  await login(page);
  await expect(page.getByRole("status").filter({ hasText: "Live" })).toBeVisible({ timeout: 20_000 });
});
