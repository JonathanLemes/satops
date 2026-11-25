import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/screenshots",
  timeout: 180_000,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: process.env.SATOPS_E2E_URL ?? "http://127.0.0.1:8470",
    locale: "en-US",
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
    colorScheme: "light",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 } } }],
});
