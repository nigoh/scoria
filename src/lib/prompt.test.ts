import { describe, it, expect } from "vitest";
import { generateSearchPrompt, ResearchInput } from "./prompt";

describe("generateSearchPrompt", () => {
  it("研究テーマと目的からプロンプトを生成する", () => {
    const input: ResearchInput = {
      theme: "機械学習を用いた自然言語処理",
      purpose: "最新の研究動向を把握する",
    };

    const result = generateSearchPrompt(input);

    expect(result.type).toBe("literature_search");
    expect(result.prompt).toContain(input.theme);
    expect(result.prompt).toContain(input.purpose);
  });

  it("キーワードが含まれる場合はプロンプトに反映する", () => {
    const input: ResearchInput = {
      theme: "深層学習",
      purpose: "画像認識の精度向上",
      keywords: ["CNN", "転移学習", "データ拡張"],
    };

    const result = generateSearchPrompt(input);

    expect(result.prompt).toContain("CNN");
    expect(result.prompt).toContain("転移学習");
    expect(result.prompt).toContain("データ拡張");
  });

  it("キーワードが空の場合はキーワードセクションを含まない", () => {
    const input: ResearchInput = {
      theme: "量子コンピューティング",
      purpose: "基礎理論の理解",
      keywords: [],
    };

    const result = generateSearchPrompt(input);

    expect(result.prompt).not.toContain("キーワード:");
  });

  it("キーワードが未定義の場合はキーワードセクションを含まない", () => {
    const input: ResearchInput = {
      theme: "バイオインフォマティクス",
      purpose: "ゲノム解析手法の調査",
    };

    const result = generateSearchPrompt(input);

    expect(result.prompt).not.toContain("キーワード:");
  });
});
