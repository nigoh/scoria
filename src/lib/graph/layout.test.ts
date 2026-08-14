import { describe, it, expect } from "vitest";
import { layoutGraph, LAYOUT_PADDING } from "./layout";
import { buildGraph } from "./build";
import type { PaperSummary } from "@/types";

// Verifies: REQ-GRAPH-005

function paper(id: string, refs: string[] = []): PaperSummary {
  return { id, title: id, year: null, authors: [], citedByCount: 0, referencedWorks: refs };
}

const seed = paper("S", ["X1", "X2", "X3"]);
const pool = [
  paper("C1", ["X1", "X2"]),
  paper("C2", ["X2", "X3"]),
  paper("C3", ["X1"]),
  paper("C4", ["X3", "X1"]),
];
const graph = buildGraph(seed, pool);

describe("layoutGraph", () => {
  it("全ノードに有限の座標が与えられ、境界の内側に収まる", () => {
    const positions = layoutGraph(graph, 800, 600);
    expect(positions).toHaveLength(graph.nodes.length);
    for (const p of positions) {
      expect(Number.isFinite(p.x)).toBe(true);
      expect(Number.isFinite(p.y)).toBe(true);
      expect(p.x).toBeGreaterThanOrEqual(LAYOUT_PADDING);
      expect(p.x).toBeLessThanOrEqual(800 - LAYOUT_PADDING);
      expect(p.y).toBeGreaterThanOrEqual(LAYOUT_PADDING);
      expect(p.y).toBeLessThanOrEqual(600 - LAYOUT_PADDING);
    }
  });

  it("種論文は中央に固定される", () => {
    const positions = layoutGraph(graph, 800, 600);
    const seedPos = positions.find((p) => p.id === "S");
    expect(seedPos).toEqual({ id: "S", x: 400, y: 300 });
  });

  it("ノード同士が同一座標に潰れない", () => {
    const positions = layoutGraph(graph, 800, 600);
    const keys = positions.map((p) => `${Math.round(p.x)},${Math.round(p.y)}`);
    expect(new Set(keys).size).toBe(keys.length);
  });

  it("同一入力なら同一レイアウト（決定論。乱数を使わない）", () => {
    expect(layoutGraph(graph, 800, 600)).toEqual(layoutGraph(graph, 800, 600));
  });

  it("ノード 1 件（種のみ）でも安全に配置される", () => {
    const solo = buildGraph(seed, []);
    const positions = layoutGraph(solo, 400, 400);
    expect(positions).toEqual([{ id: "S", x: 200, y: 200 }]);
  });
});
