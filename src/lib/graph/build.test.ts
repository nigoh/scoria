import { describe, it, expect } from "vitest";
import { buildGraph, MAX_GRAPH_NODES, CANDIDATE_EDGE_THRESHOLD } from "./build";
import type { PaperSummary } from "@/types";

// Verifies: REQ-GRAPH-004, NFR-PERF-001

function paper(id: string, refs: string[] = []): PaperSummary {
  return { id, title: id, year: null, authors: [], citedByCount: 0, referencedWorks: refs };
}

const seed = paper("S", ["X1", "X2", "X3", "X4"]);

describe("buildGraph", () => {
  it("ノードは種論文＋類似度上位で上限以下、種論文は必ず含まれる", () => {
    // 全候補が種と参照を共有する（スコア > 0）
    const pool = Array.from({ length: 60 }, (_, i) => paper(`C${i}`, ["X1", `only-${i}`]));
    const graph = buildGraph(seed, pool);

    expect(graph.nodes.length).toBeLessThanOrEqual(MAX_GRAPH_NODES);
    expect(graph.nodes.filter((n) => n.isSeed)).toHaveLength(1);
    expect(graph.nodes.find((n) => n.isSeed)?.paper.id).toBe("S");
  });

  it("類似度 0 の候補はグラフに入らない（孤立ノードなし）", () => {
    const related = paper("C1", ["X1", "X2"]);
    const unrelated = paper("C2", ["Q1"]);
    const graph = buildGraph(seed, [related, unrelated]);

    const ids = graph.nodes.map((n) => n.paper.id);
    expect(ids).toContain("C1");
    expect(ids).not.toContain("C2");
  });

  it("候補ノードはすべて種論文とのエッジを持つ", () => {
    const pool = [paper("C1", ["X1"]), paper("C2", ["X2", "X3"])];
    const graph = buildGraph(seed, pool);

    for (const node of graph.nodes.filter((n) => !n.isSeed)) {
      const hasSeedEdge = graph.edges.some(
        (e) =>
          (e.source === "S" && e.target === node.paper.id) ||
          (e.source === node.paper.id && e.target === "S"),
      );
      expect(hasSeedEdge).toBe(true);
    }
  });

  it("候補同士のエッジは類似度が閾値以上の組だけ", () => {
    // C1-C2 は参照を 2 件共有（閾値以上）、C1-C3 は 1 件（閾値未満）
    const c1 = paper("C1", ["X1", "Y1", "Y2"]);
    const c2 = paper("C2", ["X2", "Y1", "Y2"]);
    const c3 = paper("C3", ["X3", "Y1"]);
    expect(CANDIDATE_EDGE_THRESHOLD).toBe(2);
    const graph = buildGraph(seed, [c1, c2, c3]);

    const between = (a: string, b: string) =>
      graph.edges.some(
        (e) => (e.source === a && e.target === b) || (e.source === b && e.target === a),
      );
    expect(between("C1", "C2")).toBe(true);
    expect(between("C1", "C3")).toBe(false);
  });

  it("空プールなら種論文だけのグラフ（例外で落ちない）", () => {
    const graph = buildGraph(seed, []);
    expect(graph.nodes).toHaveLength(1);
    expect(graph.nodes[0].isSeed).toBe(true);
    expect(graph.edges).toEqual([]);
  });

  it("同一入力なら同一グラフ（決定論）", () => {
    const pool = Array.from({ length: 10 }, (_, i) => paper(`C${i}`, ["X1", "X2"]));
    expect(buildGraph(seed, pool)).toEqual(buildGraph(seed, pool));
  });
});
