import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 60000,
  retries: 0,
  use: {
    baseURL: "http://localhost:5199",
    headless: true,
    launchOptions: {
      executablePath: "/root/.cache/ms-playwright/chromium-1194/chrome-linux/chrome",
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    },
  },
  webServer: {
    command: "npm run dev -- --port 5199",
    port: 5199,
    reuseExistingServer: true,
  },
});
