import type { PaperSummary } from "@/types";

/**
 * 選択論文群を AI 設計の brief 文面に整形する（REQ-GRAPH-006）。
 *
 * 実在論文の書誌情報（タイトル・著者・年・OpenAlex ID）だけを並べ、欠落した情報は
 * 補わない。この一覧が AI 設計（ADR-0027）の根拠になり、幻覚引用の対策になる。
 */

const MAX_AUTHORS = 3;

export function formatPaperLine(paper: PaperSummary): string {
  const segments: string[] = [`『${paper.title}』`];

  if (paper.authors.length > 0) {
    const named = paper.authors.slice(0, MAX_AUTHORS).join(", ");
    segments.push(paper.authors.length > MAX_AUTHORS ? `${named} ほか` : named);
  }
  if (paper.year !== null) {
    segments.push(`(${paper.year})`);
  }
  segments.push(`— OpenAlex: ${paper.id}`);

  return `- ${segments.join(" ")}`;
}

export function formatPapersForBrief(papers: PaperSummary[]): string {
  if (papers.length === 0) return "";
  return [
    "次の実在論文（OpenAlex ID 付き）を土台に、この文献群を扱う研究を支援する拡張を設計してください。",
    "",
    "## 参考文献",
    ...papers.map(formatPaperLine),
  ].join("\n");
}
