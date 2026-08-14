import { test, expect } from "@playwright/test";

// Verifies: REQ-GRAPH-005, REQ-GRAPH-006

const goto = async (page: import("@playwright/test").Page, path: string) => {
  await page.goto(`http://localhost:5199${path}`, {
    waitUntil: "domcontentloaded",
  });
};

/** OpenAlex 生応答の 1 work（ブラウザ直呼びのためモックでも実 API の形状を守る） */
const rawWork = (id: string, title: string, refs: string[]) => ({
  id: `https://openalex.org/${id}`,
  title,
  publication_year: 2019,
  cited_by_count: 10,
  authorships: [{ author: { display_name: "Alice" } }],
  referenced_works: refs.map((r) => `https://openalex.org/${r}`),
});

const SEED = rawWork("W1", "Grounded Theory Methods", ["W10", "W11", "W12"]);
const DETAILS: Record<string, ReturnType<typeof rawWork>> = {
  W10: rawWork("W10", "Open Coding Practices", ["R1", "R2"]),
  W11: rawWork("W11", "Axial Coding in Qualitative Research", ["R1", "R2", "R3"]),
  W12: rawWork("W12", "Unrelated Statistics Yearbook", ["R9"]),
};
// C1 が種論文と W10/W11 を共引用し、参照も種論文と重なる（類似度の根拠になる）
const CITING = [rawWork("C1", "A Review of Grounded Theory", ["W1", "W10", "W11"])];

test.describe("論文グラフ探索（OpenAlex モック）", () => {
  test.beforeEach(async ({ page }) => {
    await page.route("https://api.openalex.org/**", async (route) => {
      const url = new URL(route.request().url());
      const filter = url.searchParams.get("filter") ?? "";
      let results: unknown[] = [];
      if (url.searchParams.has("search")) {
        results = [SEED];
      } else if (filter.startsWith("openalex_id:")) {
        results = filter
          .slice("openalex_id:".length)
          .split("|")
          .map((id) => DETAILS[id])
          .filter(Boolean);
      } else if (filter.startsWith("cites:")) {
        results = url.searchParams.get("page") === "1" ? CITING : [];
      }
      await route.fulfill({
        status: 200,
        headers: {
          "access-control-allow-origin": "*",
          "content-type": "application/json",
        },
        body: JSON.stringify({ results }),
      });
    });
  });

  test("検索 → 類似グラフ → 選択 → AI 設計への brief 引き渡し", async ({ page }) => {
    await goto(page, "/graph");

    // 検索して種論文を選ぶ
    await page.getByLabel("論文検索").fill("grounded theory");
    await page.getByRole("button", { name: "検索" }).click();
    await page.getByRole("button", { name: /Grounded Theory Methods/ }).click();

    // グラフ: 類似度のある論文だけがノードになり、種論文は選択済みで始まる
    await expect(page.getByText("選択中 [1]")).toBeVisible();
    const graphArea = page.getByRole("group", { name: "論文の類似グラフ" });
    await expect(
      graphArea.getByRole("button", { name: "A Review of Grounded Theory" }),
    ).toBeVisible();
    await expect(
      graphArea.getByRole("button", { name: "Open Coding Practices" }),
    ).toBeVisible();
    // 引用関係が繋がらない論文はグラフに入らない（REQ-GRAPH-004 の帰結を画面で確認）
    await expect(
      graphArea.getByRole("button", { name: "Unrelated Statistics Yearbook" }),
    ).toHaveCount(0);

    // ノードをクリックして選択に加える
    await graphArea.getByRole("button", { name: "A Review of Grounded Theory" }).click();
    await expect(page.getByText("選択中 [2]")).toBeVisible();

    // ビルダーへ引き渡すと AI 設計モード・brief 入力済みで開く
    await page.getByRole("button", { name: "AI 設計に送る" }).click();
    await expect(page).toHaveURL(/\/builder/);
    await page.getByText("スキル（Slash Command）").click();
    await page.getByRole("button", { name: "次へ" }).click();

    const brief = page.locator("#ai-brief");
    await expect(brief).toBeVisible();
    await expect(brief).toHaveValue(/Grounded Theory Methods/);
    await expect(brief).toHaveValue(/OpenAlex: W1\b/);
    await expect(brief).toHaveValue(/A Review of Grounded Theory/);
  });

  test("OpenAlex 障害時はエラーメッセージが表示される", async ({ page }) => {
    await page.unroute("https://api.openalex.org/**");
    await page.route("https://api.openalex.org/**", (route) =>
      route.fulfill({
        status: 429,
        headers: { "access-control-allow-origin": "*" },
        body: "slow down",
      }),
    );
    await goto(page, "/graph");
    await page.getByLabel("論文検索").fill("anything");
    await page.getByRole("button", { name: "検索" }).click();
    await expect(page.getByRole("alert")).toContainText("混み合って");
  });
});
