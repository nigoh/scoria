import { test, expect } from "@playwright/test";

const goto = async (page: import("@playwright/test").Page, path: string) => {
  await page.goto(`http://localhost:5199${path}`, {
    waitUntil: "domcontentloaded",
  });
};

test.describe("Scoria E2E - Claude Code Extension Generator", () => {
  test("ホームページが正しく表示される", async ({ page }) => {
    await goto(page, "/");
    await expect(
      page.getByRole("heading", { name: /学術研究を加速する/ }),
    ).toBeVisible();
    await expect(page.getByText("拡張を作成する").first()).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "拡張タイプを選択" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "ZIPでダウンロード" }),
    ).toBeVisible();
  });

  test("ビルダーページに遷移できる", async ({ page }) => {
    await goto(page, "/");
    await page.getByRole("link", { name: "ビルダー" }).click();
    await expect(page).toHaveURL(/\/builder/);
    await expect(
      page.getByRole("heading", { name: "拡張タイプを選択" }),
    ).toBeVisible();
  });

  test("ウィザード全フロー: スキル生成", async ({ page }) => {
    await goto(page, "/builder");

    // Step 1: 拡張タイプ選択
    await expect(
      page.getByRole("heading", { name: "拡張タイプを選択" }),
    ).toBeVisible();
    await page.getByText("スキル（Slash Command）").click();
    await page.getByRole("button", { name: "次へ" }).click();

    // Step 2: テンプレート選択 & 基本設定
    await expect(
      page.getByRole("heading", { name: "テンプレート & 基本設定" }),
    ).toBeVisible();
    await page.getByText("系統的文献レビュー").first().click();
    const nameInput = page.locator("#ext-name");
    await expect(nameInput).toHaveValue("systematic-review");
    await page.getByRole("button", { name: "次へ" }).click();

    // Step 3: 詳細設定
    await expect(
      page.getByRole("heading", { name: "詳細設定" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "生成" }).click();

    // Step 4: 内容編集
    await expect(
      page.getByRole("heading", { name: "内容を編集" }),
    ).toBeVisible();
    await expect(page.getByText("SKILL.md").first()).toBeVisible();

    // プレビュータブでファイル内容確認
    await page.getByRole("tab", { name: "プレビュー" }).click();
    await expect(
      page.getByText("name: systematic-review"),
    ).toBeVisible();

    // ZIPダウンロードボタン
    await expect(
      page.getByRole("button", { name: /ZIPダウンロード/ }),
    ).toBeEnabled();
  });

  test("ウィザード全フロー: エージェント生成", async ({ page }) => {
    await goto(page, "/builder");

    await page.getByText("エージェント（Subagent）").click();
    await page.getByRole("button", { name: "次へ" }).click();

    await page.getByText("メタ分析支援").first().click();
    await expect(page.locator("#ext-name")).toHaveValue("meta-analysis-agent");
    await page.getByRole("button", { name: "次へ" }).click();

    await expect(page.getByText("最大ターン数")).toBeVisible();
    await page.getByRole("button", { name: "生成" }).click();

    await page.getByRole("tab", { name: "プレビュー" }).click();
    await expect(page.getByText("name: meta-analysis-agent")).toBeVisible();
    await expect(page.getByText("maxTurns:")).toBeVisible();
  });

  test("ウィザード全フロー: プラグインパッケージ生成", async ({ page }) => {
    await goto(page, "/builder");

    await page.getByRole("button", { name: "プラグインパッケージ" }).click();
    await page.getByRole("button", { name: "次へ" }).click();

    await page.getByText("引用・参考文献チェック").first().click();
    await page.getByRole("button", { name: "次へ" }).click();

    await expect(page.getByText("スキル（SKILL.md）")).toBeVisible();
    await expect(page.getByText("エージェント（agent.md）")).toBeVisible();
    await page.getByRole("button", { name: "生成" }).click();

    await expect(page.getByText("SKILL.md").first()).toBeVisible();
    await expect(page.getByText("CLAUDE.md").first()).toBeVisible();
  });

  test("ブロック編集が機能する", async ({ page }) => {
    await goto(page, "/builder");

    await page.getByText("スキル（Slash Command）").click();
    await page.getByRole("button", { name: "次へ" }).click();
    await page.getByText("カスタム").first().click();
    await page.locator("#ext-name").fill("my-test-skill");
    await page.getByRole("button", { name: "次へ" }).click();
    await page.getByRole("button", { name: "生成" }).click();

    await expect(
      page.getByRole("heading", { name: "内容を編集" }),
    ).toBeVisible();

    const textareas = page.locator("textarea");
    const count = await textareas.count();
    expect(count).toBeGreaterThan(0);

    const switches = page.locator("button[role='switch']");
    const switchCount = await switches.count();
    expect(switchCount).toBeGreaterThan(0);
  });

  test("ナビゲーション: 戻るボタン", async ({ page }) => {
    await goto(page, "/builder");

    await page.getByText("スキル（Slash Command）").click();
    await page.getByRole("button", { name: "次へ" }).click();
    await expect(
      page.getByRole("heading", { name: "テンプレート & 基本設定" }),
    ).toBeVisible();

    await page.getByRole("button", { name: "戻る" }).click();
    await expect(
      page.getByRole("heading", { name: "拡張タイプを選択" }),
    ).toBeVisible();
  });

  test("未選択状態では次へが無効", async ({ page }) => {
    await goto(page, "/builder");

    const nextBtn = page.getByRole("button", { name: "次へ" });
    await expect(nextBtn).toBeDisabled();

    await page.getByText("スキル（Slash Command）").click();
    await expect(nextBtn).toBeEnabled();
  });
});
