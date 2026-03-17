import type { ResearchPhase, ResearchField, PromptBlockType } from "@/types";

export interface ResearchPhaseInfo {
  id: ResearchPhase;
  labelJa: string;
  labelEn: string;
  descriptionJa: string;
  icon: string;
}

export const RESEARCH_PHASES: ResearchPhaseInfo[] = [
  {
    id: "theme_setting",
    labelJa: "テーマ設定",
    labelEn: "Theme Setting",
    descriptionJa:
      "研究テーマの探索・絞り込み。トレンド把握やギャップ発見に最適なプロンプトを生成します。",
    icon: "Compass",
  },
  {
    id: "prior_research",
    labelJa: "先行研究調査",
    labelEn: "Prior Research",
    descriptionJa:
      "既存研究の網羅的把握。系統的検索や包括的レビュー向けのプロンプトを生成します。",
    icon: "Books",
  },
  {
    id: "hypothesis_building",
    labelJa: "仮説構築",
    labelEn: "Hypothesis Building",
    descriptionJa:
      "リサーチクエスチョンの精緻化。変数関係の整理や理論的枠組みの構築を支援します。",
    icon: "Lightbulb",
  },
  {
    id: "methodology_design",
    labelJa: "方法論設計",
    labelEn: "Methodology Design",
    descriptionJa:
      "研究手法の選定・設計。方法論比較やサンプル設計に関するプロンプトを生成します。",
    icon: "FlaskConical",
  },
];

export const RESEARCH_FIELDS: ResearchField[] = [
  { id: "natural_science", labelJa: "自然科学", labelEn: "Natural Science" },
  { id: "medicine", labelJa: "医学", labelEn: "Medicine" },
  { id: "engineering", labelJa: "工学", labelEn: "Engineering" },
  {
    id: "computer_science",
    labelJa: "情報科学",
    labelEn: "Computer Science",
  },
  { id: "mathematics", labelJa: "数学", labelEn: "Mathematics" },
  { id: "physics", labelJa: "物理学", labelEn: "Physics" },
  { id: "chemistry", labelJa: "化学", labelEn: "Chemistry" },
  { id: "biology", labelJa: "生物学", labelEn: "Biology" },
  {
    id: "earth_science",
    labelJa: "地球科学",
    labelEn: "Earth Science",
  },
  { id: "agriculture", labelJa: "農学", labelEn: "Agriculture" },
  {
    id: "social_science",
    labelJa: "社会科学",
    labelEn: "Social Science",
  },
  { id: "economics", labelJa: "経済学", labelEn: "Economics" },
  { id: "psychology", labelJa: "心理学", labelEn: "Psychology" },
  { id: "education", labelJa: "教育学", labelEn: "Education" },
  { id: "law", labelJa: "法学", labelEn: "Law" },
  {
    id: "political_science",
    labelJa: "政治学",
    labelEn: "Political Science",
  },
  { id: "sociology", labelJa: "社会学", labelEn: "Sociology" },
  { id: "humanities", labelJa: "人文学", labelEn: "Humanities" },
  { id: "philosophy", labelJa: "哲学", labelEn: "Philosophy" },
  { id: "history", labelJa: "歴史学", labelEn: "History" },
  { id: "literature", labelJa: "文学", labelEn: "Literature" },
  { id: "linguistics", labelJa: "言語学", labelEn: "Linguistics" },
  { id: "art", labelJa: "芸術学", labelEn: "Art Studies" },
  {
    id: "interdisciplinary",
    labelJa: "学際的",
    labelEn: "Interdisciplinary",
  },
  { id: "other", labelJa: "その他", labelEn: "Other" },
];

export interface PromptBlockLabel {
  type: PromptBlockType;
  labelJa: string;
  labelEn: string;
}

export const PROMPT_BLOCK_LABELS: PromptBlockLabel[] = [
  { type: "role", labelJa: "役割設定", labelEn: "Role" },
  { type: "context", labelJa: "研究コンテキスト", labelEn: "Context" },
  { type: "task", labelJa: "タスク指示", labelEn: "Task" },
  { type: "format", labelJa: "出力フォーマット", labelEn: "Format" },
  { type: "constraints", labelJa: "制約条件", labelEn: "Constraints" },
];

export interface LLMModelInfo {
  id: string;
  name: string;
}

export const ANTHROPIC_MODELS: LLMModelInfo[] = [
  { id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6" },
  { id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5" },
  { id: "claude-opus-4-6", name: "Claude Opus 4.6" },
];

export const OPENAI_MODELS: LLMModelInfo[] = [
  { id: "gpt-4o", name: "GPT-4o" },
  { id: "gpt-4o-mini", name: "GPT-4o mini" },
  { id: "gpt-4-turbo", name: "GPT-4 Turbo" },
];
