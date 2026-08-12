import { describe, it, expect } from "vitest";
import { parseAiDesign, slugifyName } from "./parse";

// Verifies: REQ-AI-002
// Verifies: NFR-REL-001

const valid = {
  name: "systematic-review",
  description: "PRISMA 準拠の系統的レビューを支援する",
  blocks: [
    { label: "検索戦略", content: "PICO に分解して検索式を組む" },
    { label: "スクリーニング", content: "適格基準に沿って選別する" },
  ],
};

describe("parseAiDesign（正常系）", () => {
  it("構造が正しい応答を受け入れる", () => {
    const r = parseAiDesign(valid);
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.value.name).toBe("systematic-review");
      expect(r.value.blocks).toHaveLength(2);
    }
  });

  it("name は kebab-case に正規化される", () => {
    const r = parseAiDesign({ ...valid, name: "My Review  Helper!" });
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.value.name).toBe("my-review-helper");
  });

  it("ブロックの前後空白は落とす", () => {
    const r = parseAiDesign({
      ...valid,
      blocks: [{ label: "  手順  ", content: "  やる  " }],
    });
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.value.blocks[0]).toEqual({ label: "手順", content: "やる" });
  });
});

describe("parseAiDesign（敵対的入力は fail-closed）", () => {
  // どの壊れ方でも「例外を投げず、ok:false の理由つき結果」で返ることを固定する
  it.each([
    ["null", null],
    ["文字列", "not an object"],
    ["配列", [valid]],
    ["name 欠落", { ...valid, name: undefined }],
    ["name が数値", { ...valid, name: 42 }],
    ["name が記号のみ", { ...valid, name: "!!!" }],
    ["description 欠落", { ...valid, description: "" }],
    ["blocks 欠落", { ...valid, blocks: undefined }],
    ["blocks が空配列", { ...valid, blocks: [] }],
    ["blocks が非配列", { ...valid, blocks: "x" }],
    ["block の label 空", { ...valid, blocks: [{ label: " ", content: "x" }] }],
    ["block の content 空", { ...valid, blocks: [{ label: "x", content: "" }] }],
    ["block が非オブジェクト", { ...valid, blocks: ["x"] }],
  ])("%s → ok:false", (_name, input) => {
    const r = parseAiDesign(input);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error.length).toBeGreaterThan(0);
  });
});

describe("slugifyName", () => {
  it.each([
    ["Systematic Review", "systematic-review"],
    ["  a__b  c ", "a-b-c"],
    ["日本語のみ", ""],
    ["--lead-trail--", "lead-trail"],
  ])("%s → %s", (input, want) => {
    expect(slugifyName(input)).toBe(want);
  });
});
