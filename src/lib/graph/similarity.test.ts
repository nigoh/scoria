import { describe, it, expect } from "vitest";
import {
  bibliographicCoupling,
  coCitationCount,
  similarityScore,
  rankCandidates,
} from "./similarity";
import type { PaperSummary } from "@/types";

// Verifies: REQ-GRAPH-003

function paper(id: string, refs: string[] = []): PaperSummary {
  return { id, title: id, year: null, authors: [], citedByCount: 0, referencedWorks: refs };
}

describe("bibliographicCoupling（書誌結合）", () => {
  it("共通参照の数を返す", () => {
    const a = paper("A", ["X", "Y", "Z"]);
    const b = paper("B", ["Y", "Z", "Q"]);
    expect(bibliographicCoupling(a, b)).toBe(2);
  });

  it("参照が重ならなければ 0", () => {
    expect(bibliographicCoupling(paper("A", ["X"]), paper("B", ["Y"]))).toBe(0);
  });

  it("重複参照があっても二重に数えない", () => {
    const a = paper("A", ["X", "X", "Y"]);
    const b = paper("B", ["X"]);
    expect(bibliographicCoupling(a, b)).toBe(1);
  });
});

describe("coCitationCount（共引用）", () => {
  it("プール内で両方を引用する論文の数を返す", () => {
    const pool = [paper("P1", ["A", "B"]), paper("P2", ["A", "B", "C"]), paper("P3", ["A"])];
    expect(coCitationCount("A", "B", pool)).toBe(2);
  });

  it("自分自身は共引用の担い手に数えない", () => {
    const pool = [paper("A", ["A", "B"]), paper("P", ["A", "B"])];
    expect(coCitationCount("A", "B", pool)).toBe(1);
  });
});

describe("similarityScore と rankCandidates", () => {
  const seed = paper("S", ["X", "Y", "Z"]);

  it("類似度は書誌結合と共引用の重み和で 0 以上", () => {
    const cand = paper("C", ["X", "Y"]); // 結合 2
    const pool = [cand, paper("P", ["S", "C"])]; // P が S と C を共引用
    const score = similarityScore(seed, cand, pool);
    expect(score).toBeGreaterThanOrEqual(0);
    expect(score).toBe(3); // 結合 2 + 共引用 1（重みは各 1）
  });

  it("完全に無関係なら 0", () => {
    const cand = paper("C", ["Q"]);
    expect(similarityScore(seed, cand, [cand])).toBe(0);
  });

  it("順位は類似度降順・同点は ID 辞書順で安定する", () => {
    const c1 = paper("C1", ["X"]);
    const c2 = paper("C2", ["X"]);
    const c3 = paper("C3", ["X", "Y"]);
    const ranked = rankCandidates(seed, [c2, c1, c3]);
    expect(ranked.map((r) => r.paper.id)).toEqual(["C3", "C1", "C2"]);
  });

  it("種論文自身は候補に含めない", () => {
    const ranked = rankCandidates(seed, [paper("S", ["X"]), paper("C", ["X"])]);
    expect(ranked.map((r) => r.paper.id)).toEqual(["C"]);
  });

  it("同一入力なら結果は常に同一（決定論）", () => {
    const pool = [paper("C1", ["X", "Y"]), paper("C2", ["Z"]), paper("C3", ["X"])];
    expect(rankCandidates(seed, pool)).toEqual(rankCandidates(seed, pool));
  });
});
