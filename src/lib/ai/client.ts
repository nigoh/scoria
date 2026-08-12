import Anthropic from "@anthropic-ai/sdk";
import type { AiOutcome, ExtensionType } from "@/types";
import { buildSystemPrompt, buildUserPrompt } from "./prompt";
import { parseAiDesign } from "./parse";
import { AI_OUTPUT_SCHEMA } from "./schema";

/**
 * Claude API 呼び出し（BYOK。ADR-0027 / REQ-AI-004）。
 *
 * キーは利用者自身のもので、ブラウザから Anthropic へ直接送る（dangerouslyAllowBrowser）。
 * 送信先はこの1箇所だけ。失敗はすべて AiOutcome の ok:false に写像し、例外を漏らさない。
 */

export const AI_MODELS = [
  { id: "claude-opus-5", labelJa: "Opus 5（最高品質・既定）" },
  { id: "claude-sonnet-5", labelJa: "Sonnet 5（バランス）" },
  { id: "claude-haiku-4-5", labelJa: "Haiku 4.5（高速・低コスト）" },
] as const;

export type AiModelId = (typeof AI_MODELS)[number]["id"];
export const DEFAULT_AI_MODEL: AiModelId = "claude-opus-5";

export interface DesignRequest {
  apiKey: string;
  model: AiModelId;
  extensionType: ExtensionType;
  outputLanguage: "ja" | "en";
  brief: string;
  nameHint: string;
  descriptionHint: string;
  /** テスト注入用。未指定なら環境の fetch */
  fetch?: typeof globalThis.fetch;
  /** テスト注入用。既定は SDK の既定（2） */
  maxRetries?: number;
}

export async function requestDesign(req: DesignRequest): Promise<AiOutcome> {
  if (req.apiKey.trim() === "") {
    return { ok: false, error: "API キーが設定されていません。設定から入力してください。" };
  }
  if (req.brief.trim() === "") {
    return { ok: false, error: "研究内容を入力してください。" };
  }

  const client = new Anthropic({
    apiKey: req.apiKey.trim(),
    dangerouslyAllowBrowser: true,
    fetch: req.fetch,
    maxRetries: req.maxRetries,
  });

  try {
    const response = await client.messages.create({
      model: req.model,
      max_tokens: 16000,
      system: buildSystemPrompt(req.extensionType, req.outputLanguage),
      messages: [
        {
          role: "user",
          content: buildUserPrompt({
            brief: req.brief,
            name: req.nameHint,
            description: req.descriptionHint,
          }),
        },
      ],
      output_config: {
        format: { type: "json_schema", schema: AI_OUTPUT_SCHEMA },
      },
    });

    // 拒否は content を読む前に判定する（安全分類器は HTTP 200 で返る）
    if (response.stop_reason === "refusal") {
      return {
        ok: false,
        error: "この内容の生成は拒否されました。研究内容の記述を変えて試してください。",
      };
    }
    if (response.stop_reason === "max_tokens") {
      return { ok: false, error: "応答が長すぎて途中で切れました。記述を短くして試してください。" };
    }

    const text = response.content.find((b) => b.type === "text")?.text ?? "";
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return { ok: false, error: "応答を解釈できませんでした。もう一度試してください。" };
    }
    return parseAiDesign(parsed);
  } catch (err) {
    if (err instanceof Anthropic.AuthenticationError) {
      return { ok: false, error: "API キーが無効です。設定を確認してください。" };
    }
    if (err instanceof Anthropic.RateLimitError) {
      return { ok: false, error: "レート制限に達しました。しばらく待ってから試してください。" };
    }
    if (err instanceof Anthropic.APIConnectionError) {
      return {
        ok: false,
        error: "Anthropic API に接続できません。ネットワークを確認してください。",
      };
    }
    if (err instanceof Anthropic.APIError) {
      return {
        ok: false,
        error: `API エラーが発生しました（${err.status ?? "?"}）。時間をおいて試してください。`,
      };
    }
    return { ok: false, error: "予期しないエラーが発生しました。もう一度試してください。" };
  }
}
