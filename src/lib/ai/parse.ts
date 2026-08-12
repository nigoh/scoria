import type { AiDesignResult, AiOutcome } from "@/types";

/**
 * AI 応答の検証・正規化（ADR-0027 / REQ-AI-002 / NFR-REL-001）。
 *
 * structured outputs で形は強制しているが、信頼境界はここに置く:
 * どんな壊れ方の入力でも例外を投げず、必ず理由つきの ok:false を返す（fail-closed）。
 */

/** name を生成パスに使える kebab-case へ正規化する。使える文字が無ければ空文字。 */
export function slugifyName(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function fail(error: string): AiOutcome {
  return { ok: false, error };
}

export function parseAiDesign(raw: unknown): AiOutcome {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return fail("応答がオブジェクトではありません");
  }
  const obj = raw as Record<string, unknown>;

  if (typeof obj.name !== "string") return fail("name がありません");
  const name = slugifyName(obj.name);
  if (name === "") return fail("name を識別子（kebab-case）にできません");

  if (typeof obj.description !== "string" || obj.description.trim() === "") {
    return fail("description が空です");
  }

  if (!Array.isArray(obj.blocks) || obj.blocks.length === 0) {
    return fail("blocks が空です");
  }

  const blocks: AiDesignResult["blocks"] = [];
  for (const entry of obj.blocks) {
    if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
      return fail("blocks の要素がオブジェクトではありません");
    }
    const b = entry as Record<string, unknown>;
    if (typeof b.label !== "string" || b.label.trim() === "") {
      return fail("ブロックの label が空です");
    }
    if (typeof b.content !== "string" || b.content.trim() === "") {
      return fail(`ブロック「${b.label ?? "?"}」の content が空です`);
    }
    blocks.push({ label: b.label.trim(), content: b.content.trim() });
  }

  return {
    ok: true,
    value: { name, description: obj.description.trim(), blocks },
  };
}
