import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    globals: true,
    include: ["src/**/*.test.{ts,tsx}"],
    // 網羅率ゲート（ADR-0029）: 対象は純粋ロジック層のみ。閾値を下げる変更は
    // 品質ゲートの弱体化として扱う（ADR-0004）
    coverage: {
      provider: "v8" as const,
      include: ["src/lib/**"],
      // use*.ts は React フック（UI 層の関心が lib に残る既存例外）。純粋ロジックの
      // ゲートからは外し、UI 同様に E2E とコンポーネントテストで見る（ADR-0029）
      exclude: ["src/lib/**/*.test.*", "src/lib/use*.ts"],
      thresholds: {
        lines: 90,
        statements: 90,
        functions: 90,
        branches: 85,
      },
    },
  },
});
