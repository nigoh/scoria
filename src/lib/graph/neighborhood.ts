import type { NeighborhoodOutcome, PaperSummary, PapersOutcome } from "@/types";
import { CITING_PAGE_SIZE } from "./openalex";

/**
 * 種論文の引用近傍（参照文献＋被引用論文）の収集（REQ-GRAPH-002）。
 *
 * 共有 API の polite pool を圧迫しないため、リクエスト数と候補数に固定の上限を置く
 * （NFR-PERF-001）。取得関数は注入で受け取り、失敗はそのままエラー結果として伝播する。
 */

export const POOL_LIMIT = 200;
export const BATCH_SIZE = 50;
export const MAX_CITING_PAGES = 2;
/** 参照バッチ ≤4（200/50）＋被引用 ≤2 ほか余裕を見た上限（NFR-PERF-001 の 10 件以下） */
export const MAX_REQUESTS = 10;

export interface NeighborhoodDeps {
  fetchWorksBatch: (ids: string[]) => Promise<PapersOutcome>;
  fetchCiting: (id: string, page: number) => Promise<PapersOutcome>;
}

export async function collectNeighborhood(
  seed: PaperSummary,
  deps: NeighborhoodDeps,
): Promise<NeighborhoodOutcome> {
  let requestCount = 0;
  const collected: PaperSummary[] = [];

  // 参照文献: 上限までの ID をバッチにまとめて取得する
  const refIds = seed.referencedWorks.slice(0, POOL_LIMIT);
  for (let i = 0; i < refIds.length; i += BATCH_SIZE) {
    const batch = refIds.slice(i, i + BATCH_SIZE);
    requestCount += 1;
    const result = await deps.fetchWorksBatch(batch);
    if (!result.ok) return result;
    collected.push(...result.value);
  }

  // 被引用論文: 満杯のページが続く間だけ次ページを読む
  for (let page = 1; page <= MAX_CITING_PAGES; page += 1) {
    requestCount += 1;
    const result = await deps.fetchCiting(seed.id, page);
    if (!result.ok) return result;
    collected.push(...result.value);
    if (result.value.length < CITING_PAGE_SIZE) break;
  }

  // 種論文を除き、重複 ID を先勝ちで畳み、プール上限で打ち切る
  const seen = new Set<string>([seed.id]);
  const papers: PaperSummary[] = [];
  for (const paper of collected) {
    if (seen.has(paper.id)) continue;
    seen.add(paper.id);
    papers.push(paper);
    if (papers.length >= POOL_LIMIT) break;
  }

  return { ok: true, value: { papers, requestCount } };
}
