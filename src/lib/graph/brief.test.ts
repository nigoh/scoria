import { describe, it, expect } from "vitest";
import { formatPaperLine, formatPapersForBrief } from "./brief";
import type { PaperSummary } from "@/types";

// Verifies: REQ-GRAPH-006

function paper(over: Partial<PaperSummary>): PaperSummary {
  return {
    id: "W10",
    title: "Grounded Theory in Practice",
    year: 2018,
    authors: ["Alice", "Bob"],
    citedByCount: 12,
    referencedWorks: [],
    ...over,
  };
}

describe("formatPaperLine", () => {
  it("タイトル・著者・年・OpenAlex ID を含む引用行になる", () => {
    const line = formatPaperLine(paper({}));
    expect(line).toContain("Grounded Theory in Practice");
    expect(line).toContain("Alice");
    expect(line).toContain("2018");
    expect(line).toContain("OpenAlex: W10");
  });

  it("著者は 3 名までで、それ以上は「ほか」に畳む", () => {
    const line = formatPaperLine(paper({ authors: ["A", "B", "C", "D", "E"] }));
    expect(line).toContain("A, B, C ほか");
    expect(line).not.toContain("D");
  });

  it("欠落した情報は補われない（年不明・著者不明でも捏造しない）", () => {
    const line = formatPaperLine(paper({ year: null, authors: [] }));
    expect(line).toContain("OpenAlex: W10");
    expect(line).not.toContain("null");
    expect(line).not.toContain("不明");
    expect(line).not.toMatch(/\(\s*\)/); // 空の括弧を残さない
  });
});

describe("formatPapersForBrief", () => {
  it("全論文が 1 行ずつ入り、参考文献の見出しを持つ", () => {
    const text = formatPapersForBrief([
      paper({ id: "W10", title: "Paper One" }),
      paper({ id: "W11", title: "Paper Two" }),
    ]);
    expect(text).toContain("## 参考文献");
    expect(text).toContain("Paper One");
    expect(text).toContain("Paper Two");
    expect(text).toContain("OpenAlex: W11");
  });

  it("空の選択なら空文字列（見出しだけの断片を作らない）", () => {
    expect(formatPapersForBrief([])).toBe("");
  });
});
