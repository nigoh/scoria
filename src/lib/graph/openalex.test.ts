import { describe, it, expect, vi } from "vitest";
import {
  OPENALEX_MAILTO,
  shortId,
  buildSearchUrl,
  buildBatchUrl,
  buildCitingUrl,
  parseWork,
  searchPapers,
  fetchWorksBatch,
  fetchCiting,
  normalizeDoi,
  buildDoiUrl,
  fetchWorkByDoi,
  lookupPapers,
} from "./openalex";

// Verifies: REQ-GRAPH-001, REQ-GRAPH-002, REQ-GRAPH-007, NFR-REL-002, NFR-SEC-002, NFR-OPS-001

/** OpenAlex 生応答の 1 work（実際の API 形状の縮約） */
function rawWork(id: string, over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: `https://openalex.org/${id}`,
    title: `Paper ${id}`,
    publication_year: 2020,
    cited_by_count: 42,
    authorships: [{ author: { display_name: "Alice" } }, { author: { display_name: "Bob" } }],
    referenced_works: ["https://openalex.org/W900", "https://openalex.org/W901"],
    ...over,
  };
}

function okJson(body: unknown): typeof globalThis.fetch {
  return vi.fn(async () => new Response(JSON.stringify(body), { status: 200 }));
}

describe("shortId", () => {
  it("URL 形式は短縮 ID に、短縮形はそのまま", () => {
    expect(shortId("https://openalex.org/W2741809807")).toBe("W2741809807");
    expect(shortId("W123")).toBe("W123");
  });
});

describe("URL 構築（NFR-SEC-002 / NFR-OPS-001）", () => {
  const allowedParams = ["search", "select", "per-page", "page", "filter", "mailto"];

  it("検索 URL は works 検索で、必要フィールドだけを select する", () => {
    const url = new URL(buildSearchUrl("grounded theory"));
    expect(url.origin).toBe("https://api.openalex.org");
    expect(url.pathname).toBe("/works");
    expect(url.searchParams.get("search")).toBe("grounded theory");
    expect(url.searchParams.get("select")).toContain("referenced_works");
    expect(url.searchParams.get("select")).toContain("cited_by_count");
  });

  it("すべての URL に mailto（polite pool）が付き、許可パラメータ以外を含めない", () => {
    for (const raw of [buildSearchUrl("q"), buildBatchUrl(["W1", "W2"]), buildCitingUrl("W1", 1)]) {
      const url = new URL(raw);
      expect(url.searchParams.get("mailto")).toBe(OPENALEX_MAILTO);
      for (const key of [...url.searchParams.keys()]) {
        expect(allowedParams).toContain(key);
      }
      // API キーや個人情報のパラメータを一切含めない
      expect(url.searchParams.get("api_key")).toBeNull();
    }
  });

  it("バッチ URL は openalex_id の OR 結合フィルタになる", () => {
    const url = new URL(buildBatchUrl(["W1", "W2", "W3"]));
    expect(url.searchParams.get("filter")).toBe("openalex_id:W1|W2|W3");
  });

  it("被引用 URL は cites フィルタとページ番号を持つ", () => {
    const url = new URL(buildCitingUrl("W7", 2));
    expect(url.searchParams.get("filter")).toBe("cites:W7");
    expect(url.searchParams.get("page")).toBe("2");
  });
});

describe("parseWork（fail-closed。NFR-REL-002）", () => {
  it("正常な work は正規化され、ID は短縮形になる", () => {
    const p = parseWork(rawWork("W10"));
    expect(p).not.toBeNull();
    expect(p?.id).toBe("W10");
    expect(p?.title).toBe("Paper W10");
    expect(p?.year).toBe(2020);
    expect(p?.authors).toEqual(["Alice", "Bob"]);
    expect(p?.citedByCount).toBe(42);
    expect(p?.referencedWorks).toEqual(["W900", "W901"]);
  });

  it("欠落フィールドは安全な既定値に落ちる", () => {
    const p = parseWork({ id: "https://openalex.org/W11" });
    expect(p).toEqual({
      id: "W11",
      title: "",
      year: null,
      authors: [],
      citedByCount: 0,
      referencedWorks: [],
    });
  });

  it("型不正のフィールドは既定値に落ち、例外にならない", () => {
    const p = parseWork(
      rawWork("W12", {
        title: 123,
        publication_year: "2020",
        cited_by_count: "many",
        authorships: [{ author: null }, "junk", { author: { display_name: 5 } }],
        referenced_works: [null, 42, "https://openalex.org/W1"],
      }),
    );
    expect(p?.title).toBe("");
    expect(p?.year).toBeNull();
    expect(p?.citedByCount).toBe(0);
    expect(p?.authors).toEqual([]);
    expect(p?.referencedWorks).toEqual(["W1"]);
  });

  it("id が無い・オブジェクトでない入力は null（採用しない）", () => {
    expect(parseWork({})).toBeNull();
    expect(parseWork(null)).toBeNull();
    expect(parseWork("W1")).toBeNull();
    expect(parseWork({ id: 42 })).toBeNull();
  });
});

describe("searchPapers（REQ-GRAPH-001）", () => {
  it("応答の results を正規化して返し、壊れた要素は除外する", async () => {
    const fetchFn = okJson({ results: [rawWork("W1"), { junk: true }, rawWork("W2")] });
    const result = await searchPapers("grounded theory", fetchFn);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.map((p) => p.id)).toEqual(["W1", "W2"]);
    }
  });

  it("空白のみの検索語はリクエストせず空結果", async () => {
    const fetchFn = vi.fn();
    const result = await searchPapers("   ", fetchFn as unknown as typeof globalThis.fetch);
    expect(result).toEqual({ ok: true, value: [] });
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("429 はレート制限のエラー結果になる（例外で落ちない）", async () => {
    const fetchFn = vi.fn(async () => new Response("slow down", { status: 429 }));
    const result = await searchPapers("q", fetchFn);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain("混み合って");
  });

  it("5xx・非 JSON・ネットワーク断もエラー結果になる", async () => {
    const cases: (typeof globalThis.fetch)[] = [
      vi.fn(async () => new Response("oops", { status: 500 })),
      vi.fn(async () => new Response("<html>not json</html>", { status: 200 })),
      vi.fn(async () => {
        throw new TypeError("Failed to fetch");
      }),
    ];
    for (const fetchFn of cases) {
      const result = await searchPapers("q", fetchFn);
      expect(result.ok).toBe(false);
    }
  });

  it("results が配列でない応答はエラー結果（fail-closed）", async () => {
    const result = await searchPapers("q", okJson({ results: "broken" }));
    expect(result.ok).toBe(false);
  });
});

describe("DOI 直指定（REQ-GRAPH-007）", () => {
  it("normalizeDoi は素の DOI・URL・doi: 接頭辞を受け付け、素の DOI に揃える", () => {
    expect(normalizeDoi("10.7717/peerj.4375")).toBe("10.7717/peerj.4375");
    expect(normalizeDoi("https://doi.org/10.7717/peerj.4375")).toBe("10.7717/peerj.4375");
    expect(normalizeDoi("doi:10.1000/xyz123")).toBe("10.1000/xyz123");
    expect(normalizeDoi("  DOI:10.1000/xyz123  ")).toBe("10.1000/xyz123");
  });

  it("DOI でない入力は null（キーワード検索に回す判定になる）", () => {
    expect(normalizeDoi("grounded theory")).toBeNull();
    expect(normalizeDoi("")).toBeNull();
    expect(normalizeDoi("10.x")).toBeNull();
    expect(normalizeDoi("https://example.com/10.1000/xyz")).toBeNull();
  });

  it("DOI URL は単一 work 取得になり、mailto と select を持つ", () => {
    const url = new URL(buildDoiUrl("10.7717/peerj.4375"));
    expect(url.pathname).toBe("/works/doi:10.7717/peerj.4375");
    expect(url.searchParams.get("mailto")).toBe(OPENALEX_MAILTO);
    expect(url.searchParams.get("select")).toContain("referenced_works");
  });

  it("該当論文を 1 件の正規化済み論文として返す", async () => {
    const result = await fetchWorkByDoi("10.7717/peerj.4375", okJson(rawWork("W1")));
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.map((p) => p.id)).toEqual(["W1"]);
  });

  it("存在しない DOI（404）は見つからない旨のエラー結果になる", async () => {
    const fetchFn = vi.fn(async () => new Response("{}", { status: 404 }));
    const result = await fetchWorkByDoi("10.1000/nope", fetchFn);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain("見つかりません");
  });

  it("work の形をしていない応答はエラー結果（fail-closed）", async () => {
    const result = await fetchWorkByDoi("10.1000/xyz", okJson({ junk: true }));
    expect(result.ok).toBe(false);
  });
});

describe("lookupPapers（DOI とキーワードの振り分け）", () => {
  it("DOI 入力なら単一 work 取得の URL を呼ぶ", async () => {
    const urls: string[] = [];
    const fetchFn: typeof globalThis.fetch = async (input) => {
      urls.push(String(input));
      return new Response(JSON.stringify(rawWork("W1")));
    };
    const result = await lookupPapers("https://doi.org/10.7717/peerj.4375", fetchFn);
    expect(result.ok).toBe(true);
    expect(urls[0]).toContain("/works/doi:10.7717/peerj.4375");
  });

  it("キーワード入力なら検索 URL を呼ぶ", async () => {
    const urls: string[] = [];
    const fetchFn: typeof globalThis.fetch = async (input) => {
      urls.push(String(input));
      return new Response(JSON.stringify({ results: [rawWork("W1")] }));
    };
    await lookupPapers("grounded theory", fetchFn);
    expect(new URL(urls[0]).searchParams.get("search")).toBe("grounded theory");
  });

  it("空白のみならリクエストせず空結果", async () => {
    const fetchFn = vi.fn();
    const result = await lookupPapers("   ", fetchFn as unknown as typeof globalThis.fetch);
    expect(result).toEqual({ ok: true, value: [] });
    expect(fetchFn).not.toHaveBeenCalled();
  });
});

describe("fetchWorksBatch / fetchCiting（REQ-GRAPH-002）", () => {
  it("バッチ取得は正規化済み一覧を返す", async () => {
    const result = await fetchWorksBatch(["W1", "W2"], okJson({ results: [rawWork("W1")] }));
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value[0].id).toBe("W1");
  });

  it("空の ID 群はリクエストせず空結果", async () => {
    const fetchFn = vi.fn();
    const result = await fetchWorksBatch([], fetchFn as unknown as typeof globalThis.fetch);
    expect(result).toEqual({ ok: true, value: [] });
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("被引用取得も同じ正規化・エラー写像を通る", async () => {
    const ok = await fetchCiting("W1", 1, okJson({ results: [rawWork("W20")] }));
    expect(ok.ok).toBe(true);
    const ng = await fetchCiting("W1", 1, async () => new Response("x", { status: 503 }));
    expect(ng.ok).toBe(false);
  });
});
