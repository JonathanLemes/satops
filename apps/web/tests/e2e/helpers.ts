import { expect, type Page } from "@playwright/test";

export const ADMIN = { email: process.env.SATOPS_E2E_EMAIL ?? "", password: process.env.SATOPS_E2E_PASSWORD ?? "" };

export async function login(page: Page, email = ADMIN.email, password = ADMIN.password) {
  await page.goto("/login");
  await page.evaluate(() => localStorage.setItem("satops.locale", "en"));
  await page.reload();
  for (let attempt = 0; attempt < 3; attempt++) {
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password").fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();
    const limited = page.getByText("Too many attempts");
    const outcome = await Promise.race([
      page.waitForURL((url) => !url.pathname.startsWith("/login")).then(() => "ok"),
      limited.waitFor().then(() => "limited"),
    ]);
    if (outcome === "ok") break;
    await page.waitForTimeout(61_000);
  }
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Financial overview" })).toBeVisible();
}

export const unique = (prefix: string) => `${prefix}-${Date.now().toString(36)}`;
