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

export interface SkillConfig {
  argumentHint: string;
  allowedTools: string[];
  model: ModelChoice;
  userInvocable: boolean;
}

export interface AgentConfig {
  tools: string[];
  model: ModelChoice;
  maxTurns: number;
  researchField: string | null;
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
