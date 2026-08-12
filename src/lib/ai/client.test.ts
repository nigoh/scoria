import { describe, it, expect } from "vitest";
import { requestDesign, type DesignRequest } from "./client";

// Verifies: REQ-AI-004
// Verifies: NFR-REL-001

/** Anthropic API の応答を偽装する fetch を作る */
function fakeFetch(status: number, body: unknown): typeof globalThis.fetch {
  return async () =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });
}

function apiMessage(overrides: Record<string, unknown> = {}) {
  return {
    id: "msg_test",
    type: "message",
    role: "assistant",
    model: "claude-opus-5",
    content: [
      {
        type: "text",
        text: JSON.stringify({
          name: "systematic-review",
          description: "系統的レビューを支援する",
          blocks: [{ label: "検索戦略", content: "PICO に分解する" }],
        }),
      },
    ],
    stop_reason: "end_turn",
    stop_sequence: null,
    usage: { input_tokens: 10, output_tokens: 10 },
    ...overrides,
  };
}

function req(overrides: Partial<DesignRequest> = {}): DesignRequest {
  return {
    apiKey: "sk-ant-test",
    model: "claude-opus-5",
    extensionType: "skill",
    outputLanguage: "ja",
    brief: "系統的レビューをやりたい",
    nameHint: "",
    descriptionHint: "",
    maxRetries: 0,
    ...overrides,
  };
}

describe("requestDesign（正常系）", () => {
  it("応答を検証済みの設計結果として返す", async () => {
    const r = await requestDesign(req({ fetch: fakeFetch(200, apiMessage()) }));

    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.value.name).toBe("systematic-review");
      expect(r.value.blocks).toHaveLength(1);
    }
  });
});

describe("requestDesign（失敗の写像）", () => {
  it("キー未設定なら API を呼ばずにエラー結果", async () => {
    let called = false;
    const spy: typeof globalThis.fetch = async () => {
      called = true;
      return new Response("{}", { status: 200 });
    };
    const r = await requestDesign(req({ apiKey: "  ", fetch: spy }));

    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain("API キー");
    expect(called).toBe(false);
  });

  it("401 は「API キーが無効」", async () => {
    const r = await requestDesign(
      req({
        fetch: fakeFetch(401, {
          type: "error",
          error: { type: "authentication_error", message: "invalid x-api-key" },
        }),
      }),
    );
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain("無効");
  });

  it("429 は再試行を促す", async () => {
    const r = await requestDesign(
      req({
        fetch: fakeFetch(429, {
          type: "error",
          error: { type: "rate_limit_error", message: "rate limited" },
        }),
      }),
    );
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain("待って");
  });

  it("529 過負荷もエラー結果として返る（例外で落ちない）", async () => {
    const r = await requestDesign(
      req({
        fetch: fakeFetch(529, {
          type: "error",
          error: { type: "overloaded_error", message: "overloaded" },
        }),
      }),
    );
    expect(r.ok).toBe(false);
  });

  it("ネットワーク断はエラー結果として返る", async () => {
    const dead: typeof globalThis.fetch = async () => {
      throw new TypeError("network down");
    };
    const r = await requestDesign(req({ fetch: dead }));
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain("接続");
  });

  it("refusal は content を読まずに拒否メッセージを返す", async () => {
    const r = await requestDesign(
      req({ fetch: fakeFetch(200, apiMessage({ stop_reason: "refusal", content: [] })) }),
    );
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain("拒否");
  });

  it("応答本文が JSON でなければエラー結果", async () => {
    const r = await requestDesign(
      req({
        fetch: fakeFetch(200, apiMessage({ content: [{ type: "text", text: "not json" }] })),
      }),
    );
    expect(r.ok).toBe(false);
  });

  it("JSON だが構造が壊れていればエラー結果（parse 側で fail-closed）", async () => {
    const r = await requestDesign(
      req({
        fetch: fakeFetch(200, apiMessage({ content: [{ type: "text", text: "{}" }] })),
      }),
    );
    expect(r.ok).toBe(false);
  });
});
