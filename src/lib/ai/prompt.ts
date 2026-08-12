import type { ExtensionType } from "@/types";

/**
 * AI 設計のプロンプト構築（ADR-0027 / REQ-AI-001）。
 *
 * AI に任せるのは「ブロック（見出し＋本文）の設計」だけで、frontmatter やファイル構成は
 * 決定論ジェネレータが組み立てる。だからここでは Claude Code の書式仕様を細かく教えず、
 * 学術研究の手順設計に集中させる。
 */

const TYPE_CONTEXT: Record<ExtensionType, string> = {
  skill:
    "設計対象はスキル（.claude/skills/<name>/SKILL.md）。人が /name で起動する手続き的ワークフローで、" +
    "本文は再現可能な手順を段階的に書く。",
  agent:
    "設計対象はエージェント（.claude/agents/<name>.md）。委譲されて自律的に働く役割で、" +
    "本文は職掌・判断基準・報告形式を書く。",
  plugin:
    "設計対象はプラグイン（skills/ + agents/ を束ねた配布パッケージ）。" +
    "本文は中核となるワークフローの手順と運用ルールを書く。",
};

export function buildSystemPrompt(
  extensionType: ExtensionType,
  outputLanguage: "ja" | "en",
): string {
  const language =
    outputLanguage === "en"
      ? "Write every block label and body in English."
      : "ブロックの見出しと本文は日本語で書く。";

  return [
    "あなたは学術研究の方法論に精通した、Claude Code 拡張の設計者である。",
    "利用者は研究者で、研究の手順（系統的レビュー・メタ分析・引用チェックなど）を",
    "Claude Code の拡張として再利用できる形にしたい。",
    "",
    TYPE_CONTEXT[extensionType],
    "",
    "設計の要件:",
    "- 研究手法の正確さを最優先する（PRISMA・PICO 等の枠組みは正しく使う）",
    "- 各ブロックは独立した節（見出し label と本文 content）で、上から順に実行できる構成にする",
    "- ブロックは3〜8個。手順・判断基準・出力形式・注意事項を過不足なく含める",
    "- name は kebab-case の短い識別子、description は1文で用途が分かる説明にする",
    `- ${language}`,
    "",
    "応答は指定された JSON スキーマ（name / description / blocks）に従うこと。",
  ].join("\n");
}

export interface UserPromptInput {
  brief: string;
  name: string;
  description: string;
}

export function buildUserPrompt({ brief, name, description }: UserPromptInput): string {
  const lines = ["次の研究内容に合わせて拡張を設計してください。", "", "## 研究内容", brief.trim()];

  if (name.trim() || description.trim()) {
    lines.push("", "## 利用者の希望");
    if (name.trim()) lines.push(`- 希望する名前: ${name.trim()}`);
    if (description.trim()) lines.push(`- 希望する説明: ${description.trim()}`);
  }

  return lines.join("\n");
}
