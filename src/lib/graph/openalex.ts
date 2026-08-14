import type { PaperSummary, PapersOutcome } from "@/types";

/**
 * OpenAlex API クライアント（ADR-0028 / REQ-GRAPH-001 / REQ-GRAPH-002）。
 *
 * ブラウザから直接呼ぶ（CC0・キー不要・CORS 対応）。送信するのは検索語・論文 ID・
 * 固定の連絡先（mailto。polite pool）のみで、API キーや個人情報は含めない（NFR-SEC-002）。
 * 応答のパースは fail-closed: 欠落・型不正は安全な既定値に落とし、例外を漏らさない（NFR-REL-002）。
 */

const API_BASE = "https://api.openalex.org";

/** polite pool の連絡先（運営者。リポジトリのコミッターとして公開済みのアドレス） */
export const OPENALEX_MAILTO = "hironobunigo@gmail.com";

/** 一覧表示と類似度計算に必要なフィールドだけを要求する */
const WORK_FIELDS = "id,title,publication_year,authorships,cited_by_count,referenced_works";

export const SEARCH_PAGE_SIZE = 10;
export const CITING_PAGE_SIZE = 100;

export function shortId(idOrUrl: string): string {
  const lastSlash = idOrUrl.lastIndexOf("/");
  return lastSlash === -1 ? idOrUrl : idOrUrl.slice(lastSlash + 1);
}

function worksUrl(params: Record<string, string>): string {
  const url = new URL(`${API_BASE}/works`);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }
  url.searchParams.set("select", WORK_FIELDS);
  url.searchParams.set("mailto", OPENALEX_MAILTO);
  return url.toString();
}

export function buildSearchUrl(query: string): string {
  return worksUrl({ search: query, "per-page": String(SEARCH_PAGE_SIZE) });
}

export function buildBatchUrl(ids: string[]): string {
  return worksUrl({ filter: `openalex_id:${ids.join("|")}`, "per-page": String(ids.length) });
}

export function buildCitingUrl(id: string, page: number): string {
  return worksUrl({
    filter: `cites:${id}`,
    "per-page": String(CITING_PAGE_SIZE),
    page: String(page),
  });
}

// ─── パース（fail-closed） ─────────────────────────────────

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function asAuthors(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const names: string[] = [];
  for (const entry of value) {
    if (!isRecord(entry) || !isRecord(entry.author)) continue;
    const name = entry.author.display_name;
    if (typeof name === "string" && name !== "") names.push(name);
  }
  return names;
}

function asWorkIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((v): v is string => typeof v === "string").map(shortId);
}

/** 1 work を正規化する。id を持たない入力は採用しない（null） */
export function parseWork(raw: unknown): PaperSummary | null {
  if (!isRecord(raw) || typeof raw.id !== "string" || raw.id === "") return null;
  return {
    id: shortId(raw.id),
    title: asString(raw.title),
    year: typeof raw.publication_year === "number" ? raw.publication_year : null,
    authors: asAuthors(raw.authorships),
    citedByCount: typeof raw.cited_by_count === "number" ? raw.cited_by_count : 0,
    referencedWorks: asWorkIds(raw.referenced_works),
  };
}

// ─── 取得（エラーを結果型に写像する） ─────────────────────────

async function fetchWorkList(
  url: string,
  fetchFn: typeof globalThis.fetch,
): Promise<PapersOutcome> {
  let response: Response;
  try {
    response = await fetchFn(url);
  } catch {
    return { ok: false, error: "OpenAlex に接続できません。ネットワークを確認してください。" };
  }

  if (response.status === 429) {
    return { ok: false, error: "OpenAlex が混み合っています。少し待ってから試してください。" };
  }
  if (!response.ok) {
    return {
      ok: false,
      error: `OpenAlex がエラーを返しました（${response.status}）。時間をおいて試してください。`,
    };
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return { ok: false, error: "OpenAlex の応答を解釈できませんでした。もう一度試してください。" };
  }

  if (!isRecord(body) || !Array.isArray(body.results)) {
    return { ok: false, error: "OpenAlex の応答形式が想定と異なります。もう一度試してください。" };
  }

  const papers: PaperSummary[] = [];
  for (const raw of body.results) {
    const paper = parseWork(raw);
    if (paper !== null) papers.push(paper);
  }
  return { ok: true, value: papers };
}

export async function searchPapers(
  query: string,
  fetchFn: typeof globalThis.fetch = globalThis.fetch,
): Promise<PapersOutcome> {
  if (query.trim() === "") return { ok: true, value: [] };
  return fetchWorkList(buildSearchUrl(query.trim()), fetchFn);
}

export async function fetchWorksBatch(
  ids: string[],
  fetchFn: typeof globalThis.fetch = globalThis.fetch,
): Promise<PapersOutcome> {
  if (ids.length === 0) return { ok: true, value: [] };
  return fetchWorkList(buildBatchUrl(ids), fetchFn);
}

export async function fetchCiting(
  id: string,
  page: number,
  fetchFn: typeof globalThis.fetch = globalThis.fetch,
): Promise<PapersOutcome> {
  return fetchWorkList(buildCitingUrl(id, page), fetchFn);
}
