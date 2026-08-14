import type { PaperGraph, PaperGraphEdge, PaperSummary } from "@/types";
import { rankCandidates, similarityScore } from "./similarity";

/**
 * 類似グラフの構築（REQ-GRAPH-004）。
 *
 * ノードは種論文＋類似度上位（合計 40 件以下。NFR-PERF-001）。類似度 0 の候補は入れない
 * （全候補ノードが種論文とのエッジを持つ＝孤立ノードが出ない）。候補同士のエッジは
 * 閾値以上の組だけに絞り、毛玉グラフを避ける。
 */

export const MAX_GRAPH_NODES = 40;
export const CANDIDATE_EDGE_THRESHOLD = 2;

export function buildGraph(seed: PaperSummary, pool: PaperSummary[]): PaperGraph {
  const ranked = rankCandidates(seed, pool)
    .filter((c) => c.score > 0)
    .slice(0, MAX_GRAPH_NODES - 1);

  const nodes = [
    { paper: seed, score: 0, isSeed: true },
    ...ranked.map((c) => ({ paper: c.paper, score: c.score, isSeed: false })),
  ];

  const edges: PaperGraphEdge[] = ranked.map((c) => ({
    source: seed.id,
    target: c.paper.id,
    weight: c.score,
  }));

  for (let i = 0; i < ranked.length; i += 1) {
    for (let j = i + 1; j < ranked.length; j += 1) {
      const weight = similarityScore(ranked[i].paper, ranked[j].paper, pool);
      if (weight >= CANDIDATE_EDGE_THRESHOLD) {
        edges.push({ source: ranked[i].paper.id, target: ranked[j].paper.id, weight });
      }
    }
  }

  return { nodes, edges };
}
