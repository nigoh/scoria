import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { CircleNotch, Graph, MagnifyingGlass, Sparkle } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { searchPapers, fetchWorksBatch, fetchCiting } from "@/lib/graph/openalex";
import { collectNeighborhood } from "@/lib/graph/neighborhood";
import { buildGraph } from "@/lib/graph/build";
import { layoutGraph, type NodePosition } from "@/lib/graph/layout";
import { formatPapersForBrief } from "@/lib/graph/brief";
import { useWizardStore } from "@/stores/wizardStore";
import type { PaperGraph, PaperSummary } from "@/types";
import { GraphView } from "./GraphView";

/**
 * 論文グラフ探索（ADR-0028）。検索 → 種論文選択 → 類似グラフ → 選択論文を
 * AI 設計（ADR-0027）の brief に引き渡す。データ取得・類似度・レイアウトは
 * すべて lib/graph の純粋ロジックで、この画面は状態の束ねだけを持つ。
 */

const VIEW_WIDTH = 800;
const VIEW_HEIGHT = 600;

type Busy = "idle" | "search" | "collect";

export function GraphExplorer() {
  const navigate = useNavigate();
  const { setDesignMode, setAiBrief } = useWizardStore();

  const [query, setQuery] = useState("");
  const [results, setResults] = useState<PaperSummary[]>([]);
  const [busy, setBusy] = useState<Busy>("idle");
  const [error, setError] = useState<string | null>(null);
  const [graph, setGraph] = useState<PaperGraph | null>(null);
  const [positions, setPositions] = useState<NodePosition[]>([]);
  const [selected, setSelected] = useState<Map<string, PaperSummary>>(new Map());

  const handleSearch = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy("search");
    setError(null);
    const result = await searchPapers(query);
    setBusy("idle");
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setResults(result.value);
  };

  const handleSelectSeed = async (seed: PaperSummary) => {
    setBusy("collect");
    setError(null);
    const result = await collectNeighborhood(seed, { fetchWorksBatch, fetchCiting });
    setBusy("idle");
    if (!result.ok) {
      setError(result.error);
      return;
    }
    const built = buildGraph(seed, result.value.papers);
    setGraph(built);
    setPositions(layoutGraph(built, VIEW_WIDTH, VIEW_HEIGHT));
    setSelected(new Map([[seed.id, seed]]));
  };

  const toggleSelect = (paper: PaperSummary) => {
    setSelected((prev) => {
      const next = new Map(prev);
      if (next.has(paper.id)) {
        next.delete(paper.id);
      } else {
        next.set(paper.id, paper);
      }
      return next;
    });
  };

  const handleSendToBuilder = () => {
    setDesignMode("ai");
    setAiBrief(formatPapersForBrief([...selected.values()]));
    void navigate("/builder");
  };

  return (
    <div className="flex h-full flex-col md:flex-row">
      <div className="flex w-full flex-col border-b border-border md:w-96 md:border-b-0 md:border-r">
        <form onSubmit={handleSearch} className="flex gap-2 border-b border-border p-3">
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="キーワードで種論文を検索"
            aria-label="論文検索"
          />
          <Button type="submit" variant="secondary" disabled={busy !== "idle"} className="gap-1">
            {busy === "search" ? (
              <CircleNotch size={16} className="animate-spin" />
            ) : (
              <MagnifyingGlass size={16} />
            )}
            検索
          </Button>
        </form>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {results.length === 0 && (
            <p className="p-4 font-sans text-xs text-muted-foreground">
              OpenAlex（CC0 の学術データベース）から論文を検索し、種論文を選ぶと
              引用関係の近さでグラフが組まれます。
            </p>
          )}
          <ul>
            {results.map((paper) => (
              <li key={paper.id}>
                <button
                  type="button"
                  onClick={() => void handleSelectSeed(paper)}
                  disabled={busy !== "idle"}
                  className="w-full border-b border-border px-4 py-2 text-left transition-colors hover:bg-accent disabled:opacity-50"
                >
                  <span className="block truncate text-sm">{paper.title}</span>
                  <span className="block text-xs text-muted-foreground">
                    {paper.year ?? "----"} · 被引用 {paper.citedByCount} ·{" "}
                    <span className="text-signal">{paper.id}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>

        <div className="border-t border-border p-3">
          <h2 className="mb-2 text-xs text-muted-foreground">選択中 [{selected.size}]</h2>
          <ul className="mb-3 max-h-32 overflow-y-auto">
            {[...selected.values()].map((paper) => (
              <li key={paper.id} className="truncate text-xs" title={paper.title}>
                <span className="text-signal">{paper.id}</span> {paper.title}
              </li>
            ))}
          </ul>
          <Button
            onClick={handleSendToBuilder}
            disabled={selected.size === 0}
            className="w-full gap-1"
          >
            <Sparkle size={16} />
            AI 設計に送る
          </Button>
        </div>
      </div>

      <div className="relative min-h-0 flex-1">
        {error && (
          <div
            role="alert"
            className="border-b border-destructive/40 bg-destructive/10 px-4 py-2 font-sans text-xs text-destructive"
          >
            {error}
          </div>
        )}
        {busy === "collect" && (
          <div className="absolute inset-0 z-10 flex items-center justify-center bg-background/70">
            <p className="flex items-center gap-2 text-sm text-muted-foreground">
              <CircleNotch size={18} className="animate-spin" />
              引用近傍を収集中…
            </p>
          </div>
        )}
        {graph ? (
          <GraphView
            graph={graph}
            positions={positions}
            selectedIds={new Set(selected.keys())}
            onToggle={toggleSelect}
            width={VIEW_WIDTH}
            height={VIEW_HEIGHT}
          />
        ) : (
          <div className="flex h-full items-center justify-center">
            <p className="flex items-center gap-2 text-sm text-muted-foreground">
              <Graph size={20} />
              種論文を選ぶとここにグラフが表示されます
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
