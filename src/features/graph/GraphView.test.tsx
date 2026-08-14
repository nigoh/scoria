// @vitest-environment jsdom
import { describe, it, expect, vi } from "vitest";
import { render, fireEvent } from "@testing-library/react";
import { GraphView } from "./GraphView";
import type { PaperGraph, PaperSummary } from "@/types";

// Verifies: REQ-GRAPH-005, REQ-GRAPH-008

function paper(id: string, title: string): PaperSummary {
  return { id, title, year: 2020, authors: [], citedByCount: 0, referencedWorks: [] };
}

const seed = paper("W1", "Seed Paper");
const cand = paper("W2", "Candidate Paper");

const graph: PaperGraph = {
  nodes: [
    { paper: seed, score: 0, isSeed: true },
    { paper: cand, score: 2, isSeed: false },
  ],
  edges: [{ source: "W1", target: "W2", weight: 2 }],
};

const positions = [
  { id: "W1", x: 400, y: 300 },
  { id: "W2", x: 200, y: 150 },
];

function renderView(over: Partial<Parameters<typeof GraphView>[0]> = {}) {
  const onToggle = vi.fn();
  const onReseed = vi.fn();
  const utils = render(
    <GraphView
      graph={graph}
      positions={positions}
      selectedIds={new Set(["W1"])}
      onToggle={onToggle}
      onReseed={onReseed}
      width={800}
      height={600}
      {...over}
    />,
  );
  return { ...utils, onToggle, onReseed };
}

describe("GraphView", () => {
  it("全ノードがボタンとして描画され、選択状態が aria-pressed に出る", () => {
    const { getByRole } = renderView();
    expect(getByRole("button", { name: "Seed Paper" }).getAttribute("aria-pressed")).toBe("true");
    expect(getByRole("button", { name: "Candidate Paper" }).getAttribute("aria-pressed")).toBe(
      "false",
    );
  });

  it("クリックで onToggle がその論文を引数に呼ばれる", () => {
    const { getByRole, onToggle, onReseed } = renderView();
    fireEvent.click(getByRole("button", { name: "Candidate Paper" }));
    expect(onToggle).toHaveBeenCalledWith(cand);
    expect(onReseed).not.toHaveBeenCalled();
  });

  it("ダブルクリックで onReseed がその論文を引数に呼ばれる（再探索）", () => {
    const { getByRole, onReseed } = renderView();
    fireEvent.doubleClick(getByRole("button", { name: "Candidate Paper" }));
    expect(onReseed).toHaveBeenCalledWith(cand);
  });

  it("キーボード（Enter / Space）でも選択をトグルできる", () => {
    const { getByRole, onToggle } = renderView();
    fireEvent.keyDown(getByRole("button", { name: "Candidate Paper" }), { key: "Enter" });
    fireEvent.keyDown(getByRole("button", { name: "Candidate Paper" }), { key: " " });
    expect(onToggle).toHaveBeenCalledTimes(2);
  });

  it("座標が無いノードは描画されない（レイアウトとの不整合で落ちない）", () => {
    const { queryByRole } = renderView({ positions: [{ id: "W1", x: 400, y: 300 }] });
    expect(queryByRole("button", { name: "Candidate Paper" })).toBeNull();
  });
});
