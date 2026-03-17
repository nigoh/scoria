import { nanoid } from "nanoid";
import type {
  GeneratedPromptData,
  PromptBlock,
  PromptBlockType,
  WizardFormData,
} from "@/types";
import {
  RESEARCH_PHASES,
  RESEARCH_FIELDS,
  PROMPT_BLOCK_LABELS,
  SYSTEM_BLOCK_TYPES,
  USER_BLOCK_TYPES,
} from "./constants";
import { PRESET_DATABASES } from "./databases";

/**
 * Scoria - 学術検索・文献レビュー向けAIプロンプト自動生成ツール
 */

// ─── 旧 API（後方互換・テスト維持） ─────────────────────────────

export interface ResearchInput {
  theme: string;
  purpose: string;
  keywords?: string[];
}

export interface GeneratedPrompt {
  prompt: string;
  type: "literature_search" | "literature_review" | "research_question";
}

export function generateSearchPrompt(input: ResearchInput): GeneratedPrompt {
  const keywordsSection =
    input.keywords && input.keywords.length > 0 ? `\nキーワード: ${input.keywords.join(", ")}` : "";

  const prompt = `以下の研究テーマに関する学術文献を検索してください。

研究テーマ: ${input.theme}
研究目的: ${input.purpose}${keywordsSection}

関連する学術論文、レビュー論文、メタ分析を包括的に検索し、
主要な知見をまとめてください。`;

  return { prompt, type: "literature_search" };
}

// ─── ヘルパー ────────────────────────────────────────────────────

function joinBlocks(blocks: PromptBlock[], types: PromptBlockType[]): string {
  return blocks
    .filter((b) => b.enabled && types.includes(b.type))
    .map((b) => `## ${b.labelJa}\n${b.content}`)
    .join("\n\n");
}

function buildFullText(blocks: PromptBlock[]): string {
  return blocks
    .filter((b) => b.enabled)
    .map((b) => `## ${b.labelJa}\n${b.content}`)
    .join("\n\n");
}

export function recomputeFullText(blocks: PromptBlock[]): string {
  return buildFullText(blocks);
}

export function recomputeSystemPrompt(blocks: PromptBlock[]): string {
  return joinBlocks(blocks, SYSTEM_BLOCK_TYPES);
}

export function recomputeUserPrompt(blocks: PromptBlock[]): string {
  return joinBlocks(blocks, USER_BLOCK_TYPES);
}

// ─── メイン生成関数 ──────────────────────────────────────────────

export function generateBlockedPrompt(
  formData: WizardFormData,
): GeneratedPromptData {
  const phase = RESEARCH_PHASES.find((p) => p.id === formData.phase);
  const field = RESEARCH_FIELDS.find((f) => f.id === formData.field);
  const keywords = formData.keywords.map((k) => k.value);
  const enabledDbs = PRESET_DATABASES.filter((db) =>
    formData.conditions.enabledDatabaseIds.includes(db.id),
  );
  const items = formData.comparisonItems.filter((i) => i.trim());
  const axes = formData.comparisonAxes.filter((a) => a.trim());

  const phaseName = phase?.labelJa ?? "未指定";
  const fieldName = field?.labelJa ?? "未指定";
  const keywordsText = keywords.length > 0 ? keywords.join("、") : "未指定";
  const dbNames =
    enabledDbs.length > 0
      ? enabledDbs.map((db) => db.name).join("、")
      : "主要な学術データベース";
  const lang = formData.conditions.outputLanguage === "en" ? "英語" : "日本語";
  const yearFrom = formData.conditions.yearRange.from;
  const yearTo = formData.conditions.yearRange.to;
  const yearText =
    yearFrom || yearTo ? `${yearFrom ?? ""}〜${yearTo ?? ""}年` : "指定なし";

  const contentMap: Record<PromptBlockType, string> = {
    role: buildRoleContent(phaseName, fieldName),
    guardrails: buildGuardrailsContent(dbNames),
    context: buildContextContent(fieldName, keywordsText, formData.purpose, dbNames, items, axes),
    task: buildTaskContent(phaseName, formData.purpose, items, axes),
    format: buildFormatContent(lang, phaseName, items.length > 0),
    constraints: buildConstraintsContent(yearText, dbNames, lang),
    disclaimer: buildDisclaimerContent(),
  };

  const blocks: PromptBlock[] = PROMPT_BLOCK_LABELS.map((label) => ({
    id: nanoid(),
    type: label.type,
    labelJa: label.labelJa,
    content: contentMap[label.type],
    enabled: true,
  }));

  return {
    blocks,
    systemPrompt: joinBlocks(blocks, SYSTEM_BLOCK_TYPES),
    userPrompt: joinBlocks(blocks, USER_BLOCK_TYPES),
    fullText: buildFullText(blocks),
    generatedAt: new Date().toISOString(),
  };
}

// ─── System Prompt ブロック ───────────────────────────────────────

function buildRoleContent(phaseName: string, fieldName: string): string {
  return `あなたは「${fieldName}」分野の学術研究に精通した専門アシスタントです。
現在のタスクは「${phaseName}」フェーズにおける文献調査の支援です。

以下のルールと品質基準を厳守し、研究者が効果的に先行研究を発見・整理できるよう支援してください。`;
}

function buildGuardrailsContent(dbNames: string): string {
  return `### ハルシネーション防止
- **実在が確認できない文献は絶対に引用しない**
- 確信が持てない情報には必ず以下の警告タグを付与：
  - ⚠️ [要検証] — 記憶に基づく情報で、正確性に不確実性がある
  - 🔍 [未確認] — 該当する文献を特定できなかった
  - ❌ [AI生成の可能性] — この情報はAIが生成した可能性があり、原典の確認が必要
- 情報が見つからない場合は「該当エビデンスなし」と明記し、捏造しない

### 検索戦略の透明化
回答の冒頭に以下の検索メタ情報を必ず提示：
- 使用データベース: ${dbNames}
- 検索キーワード: [使用した検索語を列挙]
- 検索期間: [対象とした出版年の範囲]
- 包含基準: [どのような研究を含めたか]
- 除外基準: [どのような研究を除外したか]

### 信頼度スコア
各情報に以下の信頼度を付与：
- ★★★: 査読付き論文から直接引用、DOI確認済み
- ★★☆: 学術ソースだが詳細な検証が未完了
- ★☆☆: 記憶ベースまたは間接的な情報源

### エビデンスピラミッド分類
引用する研究を以下の基準で分類：
- **Ia**: メタ分析・システマティックレビュー
- **Ib**: ランダム化比較試験（RCT）
- **IIa**: 準実験研究（非ランダム化比較試験）
- **IIb**: 観察研究・コホート研究
- **III**: ケーススタディ・事例報告・質的研究
- **IV**: 専門家の意見・教科書・理論的考察`;
}

function buildDisclaimerContent(): string {
  return `本回答はAIにより生成されたものです。引用された文献の正確性は必ず原典で確認してください。
- エビデンスが不十分な分野では、その旨を明確に述べ、無理に情報を埋めないこと
- 対立するエビデンスがある場合は両方を提示し、どちらかに偏らないこと
- 効果量が報告されていない研究は、その旨を明記すること`;
}

// ─── User Prompt ブロック ────────────────────────────────────────

function buildContextContent(
  fieldName: string,
  keywordsText: string,
  purpose: string,
  dbNames: string,
  items: string[],
  axes: string[],
): string {
  let text = `研究分野: ${fieldName}
キーワード: ${keywordsText}
研究目的: ${purpose || "未入力"}
対象検索DB: ${dbNames}`;

  if (items.length > 0) {
    text += `\n比較対象: ${items.map((i) => `「${i}」`).join("、")}`;
  }
  if (axes.length > 0) {
    text += `\n比較軸: ${axes.join("、")}`;
  }
  return text;
}

function buildTaskContent(
  phaseName: string,
  purpose: string,
  items: string[],
  axes: string[],
): string {
  const purposeText = purpose || "指定された研究テーマ";
  const hasComparison = items.length > 0;

  const comparisonNote = hasComparison
    ? `\n\n### 比較分析の要件\n比較対象（${items.join("、")}）について${axes.length > 0 ? `、以下の比較軸で評価してください: ${axes.join("、")}` : "、多角的な観点から比較分析してください"}。\n各比較対象について、エビデンスレベル・効果量・出典を明記してください。`
    : "";

  const taskMap: Record<string, string> = {
    テーマ設定: `以下のタスクを実行してください:
1. 「${purposeText}」に関連する最新の研究トレンドを概観する
2. 未探索の研究ギャップを3つ以上特定する
3. 各ギャップについて、なぜ重要かを簡潔に説明する
4. 今後の研究テーマ候補を優先度順に提案する${comparisonNote}`,
    先行研究調査: `以下のタスクを実行してください:
1. 「${purposeText}」に関する主要な先行研究を網羅的にリストアップする
2. 各研究の目的・方法・主要な知見を要約する
3. 研究間の共通点・相違点を比較分析する
4. 文献レビューの全体像をまとめる${comparisonNote}`,
    仮説構築: `以下のタスクを実行してください:
1. 「${purposeText}」に関する既存の理論的枠組みを整理する
2. 変数間の関係性を明確にする
3. 検証可能なリサーチクエスチョンを3つ以上提案する
4. 各仮説の理論的根拠を説明する${comparisonNote}`,
    方法論設計: `以下のタスクを実行してください:
1. 「${purposeText}」に適した研究手法を複数提案する
2. 各手法の長所・短所を比較する
3. データ収集方法とサンプルサイズの推奨を示す
4. 分析手法の選択肢とその根拠を説明する${comparisonNote}`,
  };

  return taskMap[phaseName] ?? taskMap["先行研究調査"];
}

function buildFormatContent(
  lang: string,
  phaseName: string,
  hasComparison: boolean,
): string {
  const baseFormat = `出力は${lang}で回答してください。`;

  const columns = `
### 必須カラム（各文献について）
| カラム名 | 説明 |
|---|---|
| エビデンスレベル | Ia〜IV のランク |
| 主要な知見 | 研究結果の要約（2〜3文） |
| 効果量・統計指標 | Cohen's d, OR, RR, p値, 95%CI 等（報告がある場合） |
| 出典 | 著者名, 年, ジャーナル名, DOI |
| 信頼度スコア | ★★★〜★☆☆ |
| 実務適用性 | 実務での活用可能性と条件（1〜2文） |
| 限界・注意点 | 研究の限界、一般化の制約（1〜2文） |`;

  const structureMap: Record<string, string> = {
    テーマ設定: `${baseFormat}

### 出力構造
1. **検索戦略サマリー**（使用DB、検索語、期間、包含/除外基準）
2. **研究トレンド概観**（箇条書き）
3. **研究ギャップ一覧**（番号付きリスト＋重要性の説明）
4. **研究テーマ候補**（優先度順）
5. **免責事項**
${columns}`,

    先行研究調査: `${baseFormat}

### 出力構造
1. **検索戦略サマリー**
2. **文献マトリクス表**${hasComparison ? "（比較対象×評価軸）" : ""}
3. **総合考察**（200字以内で全体的な知見の傾向を要約）
4. **推奨アクション**（実務への示唆を3点以内）
5. **免責事項**
${columns}`,

    仮説構築: `${baseFormat}

### 出力構造
1. **検索戦略サマリー**
2. **理論的枠組みの整理**（表形式）
3. **変数関係図**（テキストベース）
4. **リサーチクエスチョン候補**（番号付きリスト＋理論的根拠）
5. **免責事項**
${columns}`,

    方法論設計: `${baseFormat}

### 出力構造
1. **検索戦略サマリー**
2. **手法比較表**
3. **推奨手法とその根拠**
4. **データ収集・分析計画の骨子**
5. **免責事項**
${columns}`,
  };

  return structureMap[phaseName] ?? structureMap["先行研究調査"];
}

function buildConstraintsContent(
  yearText: string,
  dbNames: string,
  lang: string,
): string {
  return `- 対象期間: ${yearText}
- 主要な検索先: ${dbNames}
- 出力言語: ${lang}
- 査読付き論文を優先する（エビデンスレベル Ib 以上を優先的に引用）
- 可能な限り最新の研究を含める
- 推測や憶測を含めず、エビデンスに基づいた回答を行う
- 1つの比較対象に対し、可能な限り複数の独立した研究を引用する
- 効果量が報告されていない研究は、その旨を明記する`;
}
