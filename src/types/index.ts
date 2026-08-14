// ─── 拡張タイプ ──────────────────────────────────────────────

export type ExtensionType = "skill" | "agent" | "plugin";

// ─── テンプレート ────────────────────────────────────────────

export type TemplateId =
  | "repro_review"
  | "sci_test_design"
  | "research_readme"
  | "data_pipeline_doc"
  | "experiment_repro"
  | "release_archive"
  | "lab_onboarding"
  | "custom";

export interface TemplateDefinition {
  id: TemplateId;
  labelJa: string;
  labelEn: string;
  descriptionJa: string;
  supportedTypes: ExtensionType[];
}

// ─── ウィザード ──────────────────────────────────────────────

export type WizardStep = 1 | 2 | 3 | 4;

export type EffortLevel = "low" | "medium" | "high" | "max";

export interface SkillConfig {
  argumentHint: string;
  allowedTools: string[];
  model: ModelChoice;
  userInvocable: boolean;
  effort: EffortLevel | null;
  context: "inline" | "fork";
  agent: string | null;
  disableModelInvocation: boolean;
  paths: string;
  shell: "bash" | "powershell";
}

export interface AgentConfig {
  tools: string[];
  model: ModelChoice;
  maxTurns: number;
  researchField: string | null;
  effort: EffortLevel | null;
  disallowedTools: string[];
  skills: string;
  isolation: "none" | "worktree";
}

export interface PluginConfig {
  includeSkills: boolean;
  includeAgents: boolean;
  includeHooks: boolean;
  includeClaudeMd: boolean;
  includeMcp: boolean;
  includePluginJson: boolean;
  includeReadme: boolean;
  pluginVersion: string;
  pluginAuthor: string;
  pluginKeywords: string;
}

export type ModelChoice = "sonnet" | "opus" | "haiku" | "inherit";

export interface ExtensionFormData {
  extensionType: ExtensionType | null;
  templateId: TemplateId | null;
  name: string;
  description: string;
  outputLanguage: "ja" | "en";
  skillConfig: SkillConfig;
  agentConfig: AgentConfig;
  pluginConfig: PluginConfig;
  hookEntries: HookEntry[];
  mcpEntries: McpServerEntry[];
}

// ─── フック ──────────────────────────────────────────────────

export type HookType = "command" | "http" | "prompt" | "agent";

export interface HookEntry {
  id: string;
  event: string;
  matcher: string;
  hookType: HookType;
  command: string;
  url: string;
  prompt: string;
  timeout: number;
}

// ─── MCP サーバー ────────────────────────────────────────────

export interface McpServerEntry {
  id: string;
  name: string;
  command: string;
  args: string;
  env: string;
}

// ─── 生成ファイル ────────────────────────────────────────────

export interface GeneratedFile {
  path: string;
  content: string;
  language: string;
}

export interface ContentBlock {
  id: string;
  label: string;
  content: string;
  enabled: boolean;
}

export interface GeneratedExtension {
  files: GeneratedFile[];
  blocks: ContentBlock[];
  generatedAt: string;
}

// ─── 履歴 ─────────────────────────────────────────────────

export interface HistoryEntry {
  id: string;
  name: string;
  extensionType: ExtensionType;
  templateId: TemplateId;
  formData: ExtensionFormData;
  blocks: ContentBlock[];
  generatedAt: string;
  savedAt: string;
}

// ─── AI 設計（ADR-0027） ─────────────────────────────────────

export interface AiDesignResult {
  name: string;
  description: string;
  blocks: { label: string; content: string }[];
}

export type AiOutcome = { ok: true; value: AiDesignResult } | { ok: false; error: string };

// ─── 論文グラフ（ADR-0028） ─────────────────────────────────

export interface PaperSummary {
  /** OpenAlex の短縮 ID（例 W2741809807） */
  id: string;
  title: string;
  year: number | null;
  authors: string[];
  citedByCount: number;
  /** この論文が引用している論文の短縮 ID */
  referencedWorks: string[];
}

export interface PaperGraphNode {
  paper: PaperSummary;
  /** 種論文との類似度（種論文自身は 0） */
  score: number;
  isSeed: boolean;
}

export interface PaperGraphEdge {
  source: string;
  target: string;
  weight: number;
}

export interface PaperGraph {
  nodes: PaperGraphNode[];
  edges: PaperGraphEdge[];
}

export type PapersOutcome = { ok: true; value: PaperSummary[] } | { ok: false; error: string };

export type NeighborhoodOutcome =
  | { ok: true; value: { papers: PaperSummary[]; requestCount: number } }
  | { ok: false; error: string };
