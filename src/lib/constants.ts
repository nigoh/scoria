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
      "/repro-review のようなスラッシュコマンドを作成します。繰り返し使うワークフローに最適です。",
    icon: "Command",
  },
  {
    id: "agent",
    labelJa: "エージェント（Subagent）",
    labelEn: "Agent (Subagent)",
    descriptionJa:
      "再現性監査やテスト実装などの専門タスクを自律的に実行するサブエージェントを作成します。",
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
    id: "repro_review",
    labelJa: "再現性コードレビュー",
    labelEn: "Reproducibility Review",
    descriptionJa: "研究コードを再現性の観点（乱数・環境・データ来歴）でレビューします。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "sci_test_design",
    labelJa: "数値・データ処理のテスト設計",
    labelEn: "Scientific Test Design",
    descriptionJa: "許容誤差・性質ベース・ゴールデンデータの3層でテストを設計します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "research_readme",
    labelJa: "README・引用整備",
    labelEn: "README & Citation",
    descriptionJa: "第三者が使えて引用できる README と CITATION.cff を整備します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "data_pipeline_doc",
    labelJa: "データ・パイプライン文書化",
    labelEn: "Data Pipeline Docs",
    descriptionJa: "データ台帳と変換フロー図で生データから図表までを追跡可能にします。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "experiment_repro",
    labelJa: "実験の再現実行",
    labelEn: "Experiment Reproduction",
    descriptionJa: "環境検査→縮小実行→本実行→結果比較の手順で実験を再現します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "release_archive",
    labelJa: "リリース・DOI アーカイブ",
    labelEn: "Release & DOI",
    descriptionJa: "バージョン判定・CHANGELOG・DOI メタデータのリリース準備を支援します。",
    supportedTypes: ["skill", "agent", "plugin"],
  },
  {
    id: "lab_onboarding",
    labelJa: "ラボ開発規約・オンボーディング",
    labelEn: "Lab Onboarding",
    descriptionJa: "CONTRIBUTING・オンボーディング手順・イシュー運用を整備します。",
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
    command: 'echo "Bash command intercepted"',
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
    labelJa: "GitHub",
    labelEn: "GitHub",
    name: "github",
    command: "npx",
    args: "@modelcontextprotocol/server-github",
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
