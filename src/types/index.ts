// ─── 拡張タイプ ──────────────────────────────────────────────

export type ExtensionType = "skill" | "agent" | "plugin";

// ─── テンプレート ────────────────────────────────────────────

export type TemplateId =
  | "systematic_review"
  | "meta_analysis"
  | "citation_check"
  | "methodology_advisor"
  | "paper_structure"
  | "search_strategy"
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
