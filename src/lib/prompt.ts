import { nanoid } from "nanoid";
import type {
  GeneratedPromptData,
  PromptBlock,
  WizardFormData,
} from "@/types";
import { RESEARCH_PHASES, RESEARCH_FIELDS, PROMPT_BLOCK_LABELS } from "./constants";
import { PRESET_DATABASES } from "./databases";

/**
 * Scoria - 学術検索・文献レビュー向けAIプロンプト自動生成ツール
 *
 * 研究テーマや目的を入力すると、学術検索や文献レビューに最適な
 * AIプロンプトを自動生成します。
 */

export interface ResearchInput {
  /** 研究テーマ */
  theme: string;
  /** 研究目的 */
  purpose: string;
  /** キーワード (任意) */
  keywords?: string[];
}

export interface GeneratedPrompt {
  /** 生成されたプロンプト */
  prompt: string;
  /** プロンプトの種類 */
  type: "literature_search" | "literature_review" | "research_question";
}

/**
 * 研究テーマと目的から学術検索用プロンプトを生成する
 */
export function generateSearchPrompt(input: ResearchInput): GeneratedPrompt {
  const keywordsSection =
    input.keywords && input.keywords.length > 0 ? `\nキーワード: ${input.keywords.join(", ")}` : "";

  const prompt = `以下の研究テーマに関する学術文献を検索してください。

研究テーマ: ${input.theme}
研究目的: ${input.purpose}${keywordsSection}

関連する学術論文、レビュー論文、メタ分析を包括的に検索し、
主要な知見をまとめてください。`;

  return {
    prompt,
    type: "literature_search",
  };
}

// ─── ブロックベースのプロンプト生成（F-002） ───────────────────

function buildFullText(blocks: PromptBlock[]): string {
  return blocks
    .filter((b) => b.enabled)
    .map((b) => `## ${b.labelJa}\n${b.content}`)
    .join("\n\n");
}

export function generateBlockedPrompt(
  formData: WizardFormData,
): GeneratedPromptData {
  const phase = RESEARCH_PHASES.find((p) => p.id === formData.phase);
  const field = RESEARCH_FIELDS.find((f) => f.id === formData.field);
  const keywords = formData.keywords.map((k) => k.value);
  const enabledDbs = PRESET_DATABASES.filter((db) =>
    formData.conditions.enabledDatabaseIds.includes(db.id),
  );

  const phaseName = phase?.labelJa ?? "未指定";
  const fieldName = field?.labelJa ?? "未指定";
  const keywordsText =
    keywords.length > 0 ? keywords.join("、") : "未指定";
  const dbNames =
    enabledDbs.length > 0
      ? enabledDbs.map((db) => db.name).join("、")
      : "指定なし";
  const lang =
    formData.conditions.outputLanguage === "en" ? "英語" : "日本語";
  const yearFrom = formData.conditions.yearRange.from;
  const yearTo = formData.conditions.yearRange.to;
  const yearText =
    yearFrom || yearTo
      ? `${yearFrom ?? ""}〜${yearTo ?? ""}年`
      : "指定なし";

  const roleContent = buildRoleContent(phaseName);
  const contextContent = buildContextContent(
    fieldName,
    keywordsText,
    formData.purpose,
    dbNames,
  );
  const taskContent = buildTaskContent(phaseName, formData.purpose);
  const formatContent = buildFormatContent(lang);
  const constraintsContent = buildConstraintsContent(
    yearText,
    dbNames,
    lang,
  );

  const blocks: PromptBlock[] = PROMPT_BLOCK_LABELS.map((label) => ({
    id: nanoid(),
    type: label.type,
    labelJa: label.labelJa,
    content: {
      role: roleContent,
      context: contextContent,
      task: taskContent,
      format: formatContent,
      constraints: constraintsContent,
    }[label.type],
    enabled: true,
  }));

  return {
    blocks,
    fullText: buildFullText(blocks),
    generatedAt: new Date().toISOString(),
  };
}

export function recomputeFullText(blocks: PromptBlock[]): string {
  return buildFullText(blocks);
}

function buildRoleContent(phaseName: string): string {
  return `あなたは学術研究の専門家であり、「${phaseName}」フェーズにおける文献調査のスペシャリストです。研究者が効果的に先行研究を発見し、知見を整理できるよう支援してください。`;
}

function buildContextContent(
  fieldName: string,
  keywordsText: string,
  purpose: string,
  dbNames: string,
): string {
  return `研究分野: ${fieldName}
キーワード: ${keywordsText}
研究目的: ${purpose || "未入力"}
対象検索DB: ${dbNames}`;
}

function buildTaskContent(phaseName: string, purpose: string): string {
  const purposeText = purpose || "指定された研究テーマ";

  const taskMap: Record<string, string> = {
    テーマ設定: `以下のタスクを実行してください:
1. 「${purposeText}」に関連する最新の研究トレンドを概観する
2. 未探索の研究ギャップを3つ以上特定する
3. 各ギャップについて、なぜ重要かを簡潔に説明する
4. 今後の研究テーマ候補を優先度順に提案する`,
    先行研究調査: `以下のタスクを実行してください:
1. 「${purposeText}」に関する主要な先行研究を網羅的にリストアップする
2. 各研究の目的・方法・主要な知見を要約する
3. 研究間の共通点・相違点を比較分析する
4. 文献レビューの全体像をまとめる`,
    仮説構築: `以下のタスクを実行してください:
1. 「${purposeText}」に関する既存の理論的枠組みを整理する
2. 変数間の関係性を明確にする
3. 検証可能なリサーチクエスチョンを3つ以上提案する
4. 各仮説の理論的根拠を説明する`,
    方法論設計: `以下のタスクを実行してください:
1. 「${purposeText}」に適した研究手法を複数提案する
2. 各手法の長所・短所を比較する
3. データ収集方法とサンプルサイズの推奨を示す
4. 分析手法の選択肢とその根拠を説明する`,
  };

  return taskMap[phaseName] ?? taskMap["先行研究調査"];
}

function buildFormatContent(lang: string): string {
  return `出力は以下の形式で${lang}で回答してください:
- 見出しと番号付きリストを使用した構造化テキスト
- 各論文の引用情報（著者、年、タイトル、DOI）を含める
- 重要なポイントは太字で強調する
- 最後にまとめセクションを設ける`;
}

function buildConstraintsContent(
  yearText: string,
  dbNames: string,
  lang: string,
): string {
  return `- 対象期間: ${yearText}
- 主要な検索先: ${dbNames}
- 出力言語: ${lang}
- 査読付き論文を優先する
- 可能な限り最新の研究を含める
- 推測や憶測を含めず、エビデンスに基づいた回答を行う`;
}
