import type { TemplateDefinition, ExtensionType, ModelChoice } from "@/types";

// ─── 拡張タイプ ──────────────────────────────────────────────

export interface ExtensionTypeInfo {
  id: ExtensionType;
  labelJa: string;
  labelEn: string;
  descriptionJa: string;
  icon: string;
}

export const EXTENSION_TYPES: ExtensionTypeInfo[] = [
  {
    id: "skill",
    labelJa: "スキル（Slash Command）",
    labelEn: "Skill (Slash Command)",
    descriptionJa:
      "/literature-review のようなスラッシュコマンドを作成します。繰り返し使うワークフローに最適です。",
    icon: "Command",
  },
  {
    id: "agent",
    labelJa: "エージェント（Subagent）",
    labelEn: "Agent (Subagent)",
    descriptionJa:
      "文献分析やデータ整理などの専門タスクを自律的に実行するサブエージェントを作成します。",
    icon: "Robot",
  },
  {
    id: "plugin",
    labelJa: "プラグインパッケージ",
    labelEn: "Plugin Package",
    descriptionJa:
      "スキル・エージェント・フック・CLAUDE.mdを含む完全なプラグインパッケージを作成します。",
    icon: "Package",
  },
];

// ─── テンプレート ────────────────────────────────────────────

export const TEMPLATES: TemplateDefinition[] = [
  {
    id: "systematic_review",
    labelJa: "系統的文献レビュー",
    labelEn: "Systematic Review",
    descriptionJa: "PRISMA準拠の系統的レビューを支援するプロンプトを生成します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "meta_analysis",
    labelJa: "メタ分析支援",
    labelEn: "Meta-Analysis",
    descriptionJa: "効果量計算やフォレストプロット解釈を支援します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "citation_check",
    labelJa: "引用・参考文献チェック",
    labelEn: "Citation Check",
    descriptionJa: "論文の引用整合性や参考文献リストを検証します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "methodology_advisor",
    labelJa: "研究手法アドバイザー",
    labelEn: "Methodology Advisor",
    descriptionJa: "研究デザインや統計手法の選定をガイドします。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "paper_structure",
    labelJa: "論文構成支援",
    labelEn: "Paper Structure",
    descriptionJa: "IMRaD形式に沿った論文構成のアウトラインを生成します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "search_strategy",
    labelJa: "データベース検索戦略",
    labelEn: "Search Strategy",
    descriptionJa: "学術データベース向けの検索クエリ・戦略を策定します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "custom",
    labelJa: "カスタム",
    labelEn: "Custom",
    descriptionJa: "テンプレートなしで自由に作成します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
];

// ─── Claude Code ツール一覧 ─────────────────────────────────

export const CLAUDE_TOOLS = [
  "Read",
  "Edit",
  "Write",
  "Bash",
  "Glob",
  "Grep",
  "Agent",
  "WebSearch",
  "WebFetch",
  "NotebookEdit",
  "TodoWrite",
  "AskUserQuestion",
] as const;

// ─── Effort レベル ──────────────────────────────────────────

export const EFFORT_OPTIONS = [
  { id: "low", labelJa: "低", labelEn: "Low" },
  { id: "medium", labelJa: "中", labelEn: "Medium" },
  { id: "high", labelJa: "高", labelEn: "High" },
  { id: "max", labelJa: "最大（Opus 4.6のみ）", labelEn: "Max (Opus 4.6 only)" },
] as const;

// ─── エージェントタイプ ─────────────────────────────────────

export const AGENT_TYPES = ["general-purpose", "Explore", "Plan"] as const;

// ─── フックイベント ─────────────────────────────────────────

export const HOOK_EVENTS = [
  "SessionStart",
  "SessionEnd",
  "UserPromptSubmit",
  "Stop",
  "PreToolUse",
  "PostToolUse",
  "PostToolUseFailure",
  "SubagentStart",
  "SubagentStop",
  "FileChanged",
  "CwdChanged",
  "PreCompact",
  "PostCompact",
] as const;

export const HOOK_TYPES = ["command", "http", "prompt", "agent"] as const;

export interface HookPreset {
  labelJa: string;
  labelEn: string;
  event: string;
  matcher: string;
  hookType: "command" | "http" | "prompt" | "agent";
  command: string;
}

export const HOOK_PRESETS: HookPreset[] = [
  {
    labelJa: "ファイル変更時バリデーション",
    labelEn: "Validate on file change",
    event: "PostToolUse",
    matcher: "Edit|Write",
    hookType: "command",
    command: "./scripts/validate.sh",
  },
  {
    labelJa: "セッション開始セットアップ",
    labelEn: "Setup on session start",
    event: "SessionStart",
    matcher: "*",
    hookType: "command",
    command: "./scripts/setup.sh",
  },
  {
    labelJa: "Bash コマンド監査",
    labelEn: "Audit Bash commands",
    event: "PreToolUse",
    matcher: "Bash",
    hookType: "command",
    command: "echo \"Bash command intercepted\"",
  },
];

// ─── MCP テンプレート ───────────────────────────────────────

export interface McpTemplate {
  labelJa: string;
  labelEn: string;
  name: string;
  command: string;
  args: string;
}

export const MCP_TEMPLATES: McpTemplate[] = [
  {
    labelJa: "PubMed API",
    labelEn: "PubMed API",
    name: "pubmed-api",
    command: "npx",
    args: "@anthropic/mcp-pubmed",
  },
  {
    labelJa: "Semantic Scholar",
    labelEn: "Semantic Scholar",
    name: "semantic-scholar",
    command: "npx",
    args: "@anthropic/mcp-semantic-scholar",
  },
  {
    labelJa: "ファイルシステム",
    labelEn: "Filesystem",
    name: "filesystem",
    command: "npx",
    args: "@modelcontextprotocol/server-filesystem /path/to/dir",
  },
  {
    labelJa: "カスタム",
    labelEn: "Custom",
    name: "my-server",
    command: "",
    args: "",
  },
];

// ─── モデル選択肢 ───────────────────────────────────────────

export interface ModelOption {
  id: ModelChoice;
  labelJa: string;
  labelEn: string;
}

export const MODEL_OPTIONS: ModelOption[] = [
  { id: "sonnet", labelJa: "Sonnet（バランス型）", labelEn: "Sonnet (Balanced)" },
  { id: "opus", labelJa: "Opus（高性能）", labelEn: "Opus (Most Capable)" },
  { id: "haiku", labelJa: "Haiku（高速）", labelEn: "Haiku (Fast)" },
  { id: "inherit", labelJa: "継承（親セッション）", labelEn: "Inherit (Parent)" },
];

// ─── 研究分野（エージェント用） ─────────────────────────────

export interface ResearchFieldInfo {
  id: string;
  labelJa: string;
  labelEn: string;
}

export const RESEARCH_FIELDS: ResearchFieldInfo[] = [
  { id: "natural_science", labelJa: "自然科学", labelEn: "Natural Science" },
  { id: "medicine", labelJa: "医学", labelEn: "Medicine" },
  { id: "engineering", labelJa: "工学", labelEn: "Engineering" },
  { id: "computer_science", labelJa: "情報科学", labelEn: "Computer Science" },
  { id: "social_science", labelJa: "社会科学", labelEn: "Social Science" },
  { id: "humanities", labelJa: "人文学", labelEn: "Humanities" },
  { id: "interdisciplinary", labelJa: "学際的", labelEn: "Interdisciplinary" },
];

// ─── ウィザードステップラベル ────────────────────────────────

export const WIZARD_STEP_LABELS: Record<1 | 2 | 3 | 4, string> = {
  1: "拡張タイプ",
  2: "テンプレート",
  3: "詳細設定",
  4: "内容編集",
};
