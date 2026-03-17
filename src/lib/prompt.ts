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
