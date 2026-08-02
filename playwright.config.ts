import { existsSync } from "node:fs";
import { defineConfig } from "@playwright/test";

/**
 * Chromium の実行ファイルを解決する。
 *
 * 単一のパスを直書きすると、そのパスを持つ1台でしか動かない（実際に
 * `/root/.cache/ms-playwright/chromium-1194/...` が直書きされており、別環境では起動できなかった）。
 * 環境変数 → 既知の配置 → Playwright の既定解決、の順に降りていく。
 * どれも当たらなければ `undefined` を返し、Playwright 自身に解決させる。
 */
function resolveChromium(): string | undefined {
  const candidates = [
    process.env.PLAYWRIGHT_CHROMIUM_PATH,
    "/opt/pw-browsers/chromium",
    "/root/.cache/ms-playwright/chromium-1194/chrome-linux/chrome",
  ].filter((p): p is string => Boolean(p));

  return candidates.find((p) => existsSync(p));
}

export default defineConfig({
  testDir: "./e2e",
  timeout: 60000,
  retries: 0,
  use: {
    baseURL: "http://localhost:5199",
    headless: true,
    launchOptions: {
      executablePath: resolveChromium(),
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    },
  },
  webServer: {
    command: "npm run dev -- --port 5199",
    port: 5199,
    reuseExistingServer: true,
  },
});
