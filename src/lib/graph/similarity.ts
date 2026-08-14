import type { PaperSummary } from "@/types";

/**
 * 引用関係に基づく類似度（REQ-GRAPH-003）。
 *
 * 書誌結合（同じ文献を引く度合い）と共引用（同じ論文に一緒に引かれる度合い）の重み和。
 * 純粋関数・決定論で、同点は ID の辞書順で安定に並べる。
 */

export const COUPLING_WEIGHT = 1;
export const COCITATION_WEIGHT = 1;

/** 書誌結合: 2 論文が共有する参照文献の数（重複参照は 1 と数える） */
export function bibliographicCoupling(a: PaperSummary, b: PaperSummary): number {
  const refsA = new Set(a.referencedWorks);
  const refsB = new Set(b.referencedWorks);
  let shared = 0;
  for (const ref of refsA) {
    if (refsB.has(ref)) shared += 1;
  }
  return shared;
}

/** 共引用: プール内で a と b の両方を引用している論文の数（a・b 自身は数えない） */
export function coCitationCount(aId: string, bId: string, pool: PaperSummary[]): number {
  let count = 0;
  for (const paper of pool) {
    if (paper.id === aId || paper.id === bId) continue;
    const refs = new Set(paper.referencedWorks);
    if (refs.has(aId) && refs.has(bId)) count += 1;
  }
  return count;
}

export function similarityScore(a: PaperSummary, b: PaperSummary, pool: PaperSummary[]): number {
  return (
    COUPLING_WEIGHT * bibliographicCoupling(a, b) +
    COCITATION_WEIGHT * coCitationCount(a.id, b.id, pool)
  );
}

export interface RankedCandidate {
  paper: PaperSummary;
  score: number;
}

/** 種論文との類似度で降順に並べる。同点は ID 辞書順。種論文自身は除外する */
export function rankCandidates(seed: PaperSummary, pool: PaperSummary[]): RankedCandidate[] {
  return pool
    .filter((paper) => paper.id !== seed.id)
    .map((paper) => ({ paper, score: similarityScore(seed, paper, pool) }))
    .sort((a, b) => b.score - a.score || a.paper.id.localeCompare(b.paper.id));
}
