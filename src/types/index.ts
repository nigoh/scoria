// ─── 研究フェーズ（F-014） ───────────────────────────────────

export type ResearchPhase =
  | "theme_setting"
  | "prior_research"
  | "hypothesis_building"
  | "methodology_design";

export interface ResearchField {
  id: string;
  labelJa: string;
  labelEn: string;
}

// ─── ウィザード ──────────────────────────────────────────────

export type WizardStep = 1 | 2 | 3 | 4 | 5;

export interface Keyword {
  id: string;
  value: string;
}

export interface WizardConditions {
  enabledDatabaseIds: string[];
  outputLanguage: "ja" | "en";
  yearRange: { from: number | null; to: number | null };
}

export interface WizardFormData {
  phase: ResearchPhase | null;
  field: string | null;
  keywords: Keyword[];
  purpose: string;
  comparisonItems: string[];
  comparisonAxes: string[];
  conditions: WizardConditions;
}

// ─── プロンプトブロック ──────────────────────────────────────

export type PromptBlockType =
  | "role"
  | "guardrails"
  | "context"
  | "task"
  | "format"
  | "constraints"
  | "disclaimer";

export interface PromptBlock {
  id: string;
  type: PromptBlockType;
  labelJa: string;
  content: string;
  enabled: boolean;
}

export interface GeneratedPromptData {
  blocks: PromptBlock[];
  systemPrompt: string;
  userPrompt: string;
  fullText: string;
  generatedAt: string;
}

// ─── 学術 DB ─────────────────────────────────────────────────

export type DatabaseCategory =
  | "multidisciplinary_intl"
  | "field_specific_intl"
  | "tool"
  | "domestic_jp"
  | "patent";

export interface AcademicDatabase {
  id: string;
  name: string;
  category: DatabaseCategory;
  field: string;
  access: "free" | "paid" | "oa";
  url: string;
}

// ─── LLM ─────────────────────────────────────────────────────

export type LLMProvider = "anthropic" | "openai";

export interface LLMProviderConfig {
  provider: LLMProvider;
  model: string;
  encryptedApiKey: string | null;
}

export interface AppSettings {
  activeProvider: LLMProvider;
  providers: Record<LLMProvider, LLMProviderConfig>;
  enabledDatabaseIds: string[];
}

export interface LLMMessage {
  role: "user" | "assistant" | "system";
  content: string;
}
