import { expect, type Page } from "@playwright/test";

export const ADMIN = { email: process.env.SATOPS_E2E_EMAIL ?? "", password: process.env.SATOPS_E2E_PASSWORD ?? "" };

export async function login(page: Page, email = ADMIN.email, password = ADMIN.password) {
  await page.goto("/login");
  await page.evaluate(() => localStorage.setItem("satops.locale", "en"));
  await page.reload();
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: "Financial overview" })).toBeVisible();
}

export const unique = (prefix: string) => `${prefix}-${Date.now().toString(36)}`;
