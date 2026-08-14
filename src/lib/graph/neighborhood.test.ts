import { describe, it, expect } from "vitest";
import { collectNeighborhood, POOL_LIMIT, MAX_REQUESTS, BATCH_SIZE } from "./neighborhood";
import type { PaperSummary, PapersOutcome } from "@/types";

// Verifies: REQ-GRAPH-002, NFR-PERF-001

function paper(id: string, refs: string[] = []): PaperSummary {
  return {
    id,
    title: `Paper ${id}`,
    year: 2020,
    authors: [],
    citedByCount: 0,
    referencedWorks: refs,
  };
}

function ids(n: number, prefix: string): string[] {
  return Array.from({ length: n }, (_, i) => `${prefix}${i}`);
}

/** 要求された ID をそのまま論文にして返すバッチのフェイク */
function fakeBatch(calls: string[][]): (idsArg: string[]) => Promise<PapersOutcome> {
  return async (idsArg) => {
    calls.push(idsArg);
    return { ok: true, value: idsArg.map((id) => paper(id)) };
  };
}

function fakeCiting(pages: PaperSummary[][]): (id: string, page: number) => Promise<PapersOutcome> {
  return async (_id, page) => ({ ok: true, value: pages[page - 1] ?? [] });
}

describe("collectNeighborhood", () => {
  it("参照文献はバッチ上限ごとにまとめて取得される", async () => {
    const calls: string[][] = [];
    const seed = paper("W1", ids(120, "R"));
    const result = await collectNeighborhood(seed, {
      fetchWorksBatch: fakeBatch(calls),
      fetchCiting: fakeCiting([[]]),
    });

    expect(result.ok).toBe(true);
    expect(calls).toHaveLength(3); // 120 = 50 + 50 + 20
    for (const call of calls) expect(call.length).toBeLessThanOrEqual(BATCH_SIZE);
  });

  it("プールは重複が畳まれ、種論文が除外され、上限で打ち切られる", async () => {
    const calls: string[][] = [];
    const seed = paper("W1", ids(250, "R")); // 上限 200 を超える参照
    const citing = [paper("C1"), paper("W1"), paper("R0")]; // 種論文と参照の重複を含む
    const result = await collectNeighborhood(seed, {
      fetchWorksBatch: fakeBatch(calls),
      fetchCiting: fakeCiting([citing]),
    });

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    const pool = result.value.papers;
    const poolIds = pool.map((p) => p.id);
    expect(pool.length).toBeLessThanOrEqual(POOL_LIMIT);
    expect(poolIds).not.toContain("W1"); // 種論文は候補にしない
    expect(poolIds.filter((id) => id === "R0")).toHaveLength(1); // 重複は 1 件
  });

  it("リクエスト数は上限以下に収まり、件数が報告される", async () => {
    const calls: string[][] = [];
    const seed = paper("W1", ids(250, "R"));
    // 被引用 1 ページ目が満杯 → 2 ページ目まで読む
    const fullPage = Array.from({ length: 100 }, (_, i) => paper(`C${i}`));
    const result = await collectNeighborhood(seed, {
      fetchWorksBatch: fakeBatch(calls),
      fetchCiting: fakeCiting([fullPage, [paper("C200")]]),
    });

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.value.requestCount).toBeLessThanOrEqual(MAX_REQUESTS);
    expect(result.value.requestCount).toBe(calls.length + 2); // バッチ + citing 2 ページ
  });

  it("被引用が 1 ページで尽きたら 2 ページ目は読まない", async () => {
    const citingCalls: number[] = [];
    const seed = paper("W1", []);
    const result = await collectNeighborhood(seed, {
      fetchWorksBatch: fakeBatch([]),
      fetchCiting: async (_id, page) => {
        citingCalls.push(page);
        return { ok: true, value: [paper("C1")] };
      },
    });

    expect(result.ok).toBe(true);
    expect(citingCalls).toEqual([1]);
  });

  it("参照ゼロ・被引用ゼロでも空プールで成功する", async () => {
    const result = await collectNeighborhood(paper("W1", []), {
      fetchWorksBatch: fakeBatch([]),
      fetchCiting: fakeCiting([[]]),
    });
    expect(result).toEqual({ ok: true, value: { papers: [], requestCount: 1 } });
  });

  it("取得失敗はそのままエラー結果として伝播する（fail-closed）", async () => {
    const seed = paper("W1", ids(10, "R"));
    const batchFail = await collectNeighborhood(seed, {
      fetchWorksBatch: async () => ({ ok: false, error: "batch down" }),
      fetchCiting: fakeCiting([[]]),
    });
    expect(batchFail).toEqual({ ok: false, error: "batch down" });

    const citingFail = await collectNeighborhood(seed, {
      fetchWorksBatch: fakeBatch([]),
      fetchCiting: async () => ({ ok: false, error: "citing down" }),
    });
    expect(citingFail).toEqual({ ok: false, error: "citing down" });
  });

  it("同一入力なら結果は同一（決定論）", async () => {
    const seed = paper("W1", ids(60, "R"));
    const deps = { fetchWorksBatch: fakeBatch([]), fetchCiting: fakeCiting([[paper("C1")]]) };
    const a = await collectNeighborhood(seed, deps);
    const b = await collectNeighborhood(seed, deps);
    expect(a).toEqual(b);
  });
});
