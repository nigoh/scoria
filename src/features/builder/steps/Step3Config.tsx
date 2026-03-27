import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useWizardStore } from "@/stores/wizardStore";
import {
  CLAUDE_TOOLS,
  MODEL_OPTIONS,
  RESEARCH_FIELDS,
  EFFORT_OPTIONS,
  AGENT_TYPES,
} from "@/lib/constants";
import type { ModelChoice, EffortLevel } from "@/types";

export function Step3Config() {
  const { formData } = useWizardStore();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">詳細設定</h2>
        <p className="text-sm text-muted-foreground">
          拡張の動作に関する詳細を設定してください
        </p>
      </div>

      {formData.extensionType === "skill" && <SkillConfigTabs />}
      {formData.extensionType === "agent" && <AgentConfigTabs />}
      {formData.extensionType === "plugin" && <PluginConfig />}
    </div>
  );
}

// ─── スキル設定（タブ） ─────────────────────────────────────

function SkillConfigTabs() {
  return (
    <Tabs defaultValue="basic">
      <TabsList>
        <TabsTrigger value="basic">基本</TabsTrigger>
        <TabsTrigger value="advanced">詳細</TabsTrigger>
      </TabsList>
      <TabsContent value="basic">
        <SkillBasicConfig />
      </TabsContent>
      <TabsContent value="advanced">
        <SkillAdvancedConfig />
      </TabsContent>
    </Tabs>
  );
}

function SkillBasicConfig() {
  const {
    formData,
    setSkillArgumentHint,
    setSkillAllowedTools,
    setSkillModel,
    setSkillUserInvocable,
  } = useWizardStore();
  const { skillConfig } = formData;

  return (
    <div className="space-y-4 pt-4">
      <div>
        <Label htmlFor="arg-hint">引数ヒント</Label>
        <Input
          id="arg-hint"
          value={skillConfig.argumentHint}
          onChange={(e) => setSkillArgumentHint(e.target.value)}
          placeholder="[研究テーマ]"
          className="mt-1"
        />
        <p className="mt-1 text-xs text-muted-foreground">
          スラッシュコマンド実行時に表示されるヒント
        </p>
      </div>

      <div>
        <Label>許可ツール</Label>
        <div className="mt-2 flex flex-wrap gap-2">
          {CLAUDE_TOOLS.map((tool) => {
            const isActive = skillConfig.allowedTools.includes(tool);
            return (
              <button
                key={tool}
                onClick={() => {
                  const next = isActive
                    ? skillConfig.allowedTools.filter((t) => t !== tool)
                    : [...skillConfig.allowedTools, tool];
                  setSkillAllowedTools(next);
                }}
                className={`rounded-md border px-2.5 py-1 text-xs transition-colors ${
                  isActive
                    ? "border-primary bg-primary/10 text-primary"
                    : "border-border text-muted-foreground hover:border-primary/50"
                }`}
              >
                {tool}
              </button>
            );
          })}
        </div>
      </div>

      <div>
        <Label>モデル</Label>
        <Select
          value={skillConfig.model}
          onValueChange={(v) => setSkillModel(v as ModelChoice)}
        >
          <SelectTrigger className="mt-1">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {MODEL_OPTIONS.map((m) => (
              <SelectItem key={m.id} value={m.id}>
                {m.labelJa}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex items-center justify-between">
        <div>
          <Label>ユーザー実行可能</Label>
          <p className="text-xs text-muted-foreground">
            ユーザーがスラッシュコマンドで直接実行できるようにする
          </p>
        </div>
        <Switch
          checked={skillConfig.userInvocable}
          onCheckedChange={setSkillUserInvocable}
        />
      </div>
    </div>
  );
}

function SkillAdvancedConfig() {
  const {
    formData,
    setSkillEffort,
    setSkillContext,
    setSkillAgent,
    setSkillDisableModelInvocation,
    setSkillPaths,
    setSkillShell,
  } = useWizardStore();
  const { skillConfig } = formData;

  return (
    <div className="space-y-4 pt-4">
      <div>
        <Label>Effort（推論レベル）</Label>
        <Select
          value={skillConfig.effort ?? "none"}
          onValueChange={(v) => setSkillEffort(v === "none" ? null : (v as EffortLevel))}
        >
          <SelectTrigger className="mt-1">
            <SelectValue placeholder="未設定" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="none">未設定</SelectItem>
            {EFFORT_OPTIONS.map((o) => (
              <SelectItem key={o.id} value={o.id}>
                {o.labelJa}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <p className="mt-1 text-xs text-muted-foreground">
          モデルの推論の深さを制御します
        </p>
      </div>

      <div>
        <Label>コンテキスト</Label>
        <div className="mt-2 flex gap-2">
          {(["inline", "fork"] as const).map((ctx) => (
            <button
              key={ctx}
              onClick={() => setSkillContext(ctx)}
              className={`rounded-md border px-3 py-1.5 text-xs transition-colors ${
                skillConfig.context === ctx
                  ? "border-primary bg-primary/10 text-primary"
                  : "border-border text-muted-foreground hover:border-primary/50"
              }`}
            >
              {ctx === "inline" ? "Inline（同一セッション）" : "Fork（新しいセッション）"}
            </button>
          ))}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">
          inline: 現在のセッション内で実行 / fork: 独立したセッションで実行
        </p>
      </div>

      {skillConfig.context === "fork" && (
        <div>
          <Label>エージェントタイプ</Label>
          <Select
            value={skillConfig.agent ?? "none"}
            onValueChange={(v) => setSkillAgent(v === "none" ? null : v)}
          >
            <SelectTrigger className="mt-1">
              <SelectValue placeholder="未設定" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="none">未設定</SelectItem>
              {AGENT_TYPES.map((a) => (
                <SelectItem key={a} value={a}>
                  {a}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <p className="mt-1 text-xs text-muted-foreground">
            fork 実行時に使用するエージェントタイプ
          </p>
        </div>
      )}

      <div className="flex items-center justify-between">
        <div>
          <Label>自動実行無効化</Label>
          <p className="text-xs text-muted-foreground">
            モデルによる自動実行を禁止し、ユーザー起動のみに制限する
          </p>
        </div>
        <Switch
          checked={skillConfig.disableModelInvocation}
          onCheckedChange={setSkillDisableModelInvocation}
        />
      </div>

      <div>
        <Label htmlFor="skill-paths">Paths（ファイルパターン）</Label>
        <Input
          id="skill-paths"
          value={skillConfig.paths}
          onChange={(e) => setSkillPaths(e.target.value)}
          placeholder="src/**/*.ts, docs/**/*.md"
          className="mt-1"
        />
        <p className="mt-1 text-xs text-muted-foreground">
          スキルのコンテキストに含めるファイルの glob パターン
        </p>
      </div>

      <div>
        <Label>Shell</Label>
        <div className="mt-2 flex gap-2">
          {(["bash", "powershell"] as const).map((sh) => (
            <button
              key={sh}
              onClick={() => setSkillShell(sh)}
              className={`rounded-md border px-3 py-1.5 text-xs transition-colors ${
                skillConfig.shell === sh
                  ? "border-primary bg-primary/10 text-primary"
                  : "border-border text-muted-foreground hover:border-primary/50"
              }`}
            >
              {sh}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── エージェント設定（タブ） ───────────────────────────────

function AgentConfigTabs() {
  return (
    <Tabs defaultValue="basic">
      <TabsList>
        <TabsTrigger value="basic">基本</TabsTrigger>
        <TabsTrigger value="advanced">詳細</TabsTrigger>
      </TabsList>
      <TabsContent value="basic">
        <AgentBasicConfig />
      </TabsContent>
      <TabsContent value="advanced">
        <AgentAdvancedConfig />
      </TabsContent>
    </Tabs>
  );
}

function AgentBasicConfig() {
  const { formData, setAgentTools, setAgentModel, setAgentMaxTurns, setAgentResearchField } =
    useWizardStore();
  const { agentConfig } = formData;

  return (
    <div className="space-y-4 pt-4">
      <div>
        <Label>許可ツール</Label>
        <div className="mt-2 flex flex-wrap gap-2">
          {CLAUDE_TOOLS.map((tool) => {
            const isActive = agentConfig.tools.includes(tool);
            return (
              <button
                key={tool}
                onClick={() => {
                  const next = isActive
                    ? agentConfig.tools.filter((t) => t !== tool)
                    : [...agentConfig.tools, tool];
                  setAgentTools(next);
                }}
                className={`rounded-md border px-2.5 py-1 text-xs transition-colors ${
                  isActive
                    ? "border-primary bg-primary/10 text-primary"
                    : "border-border text-muted-foreground hover:border-primary/50"
                }`}
              >
                {tool}
              </button>
            );
          })}
        </div>
      </div>

      <div>
        <Label>モデル</Label>
        <Select
          value={agentConfig.model}
          onValueChange={(v) => setAgentModel(v as ModelChoice)}
        >
          <SelectTrigger className="mt-1">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {MODEL_OPTIONS.map((m) => (
              <SelectItem key={m.id} value={m.id}>
                {m.labelJa}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div>
        <Label htmlFor="max-turns">最大ターン数</Label>
        <Input
          id="max-turns"
          type="number"
          min={1}
          max={200}
          value={agentConfig.maxTurns}
          onChange={(e) => setAgentMaxTurns(Number(e.target.value))}
          className="mt-1"
        />
      </div>

      <div>
        <Label>専門研究分野（任意）</Label>
        <Select
          value={agentConfig.researchField ?? "none"}
          onValueChange={(v) => setAgentResearchField(v === "none" ? null : v)}
        >
          <SelectTrigger className="mt-1">
            <SelectValue placeholder="選択しない" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="none">選択しない</SelectItem>
            {RESEARCH_FIELDS.map((f) => (
              <SelectItem key={f.id} value={f.id}>
                {f.labelJa}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
    </div>
  );
}

function AgentAdvancedConfig() {
  const {
    formData,
    setAgentEffort,
    setAgentDisallowedTools,
    setAgentSkills,
    setAgentIsolation,
  } = useWizardStore();
  const { agentConfig } = formData;

  return (
    <div className="space-y-4 pt-4">
      <div>
        <Label>Effort（推論レベル）</Label>
        <Select
          value={agentConfig.effort ?? "none"}
          onValueChange={(v) => setAgentEffort(v === "none" ? null : (v as EffortLevel))}
        >
          <SelectTrigger className="mt-1">
            <SelectValue placeholder="未設定" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="none">未設定</SelectItem>
            {EFFORT_OPTIONS.map((o) => (
              <SelectItem key={o.id} value={o.id}>
                {o.labelJa}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <p className="mt-1 text-xs text-muted-foreground">
          モデルの推論の深さを制御します
        </p>
      </div>

      <div>
        <Label>禁止ツール</Label>
        <div className="mt-2 flex flex-wrap gap-2">
          {CLAUDE_TOOLS.map((tool) => {
            const isDisallowed = agentConfig.disallowedTools.includes(tool);
            return (
              <button
                key={tool}
                onClick={() => {
                  const next = isDisallowed
                    ? agentConfig.disallowedTools.filter((t) => t !== tool)
                    : [...agentConfig.disallowedTools, tool];
                  setAgentDisallowedTools(next);
                }}
                className={`rounded-md border px-2.5 py-1 text-xs transition-colors ${
                  isDisallowed
                    ? "border-destructive bg-destructive/10 text-destructive"
                    : "border-border text-muted-foreground hover:border-destructive/50"
                }`}
              >
                {tool}
              </button>
            );
          })}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">
          エージェントが使用できないツールを選択
        </p>
      </div>

      <div>
        <Label htmlFor="agent-skills">プリロードスキル</Label>
        <Input
          id="agent-skills"
          value={agentConfig.skills}
          onChange={(e) => setAgentSkills(e.target.value)}
          placeholder="my-skill, another-skill"
          className="mt-1"
        />
        <p className="mt-1 text-xs text-muted-foreground">
          エージェントに事前読み込みするスキル名（カンマ区切り）
        </p>
      </div>

      <div>
        <Label>Isolation</Label>
        <div className="mt-2 flex gap-2">
          {(["none", "worktree"] as const).map((iso) => (
            <button
              key={iso}
              onClick={() => setAgentIsolation(iso)}
              className={`rounded-md border px-3 py-1.5 text-xs transition-colors ${
                agentConfig.isolation === iso
                  ? "border-primary bg-primary/10 text-primary"
                  : "border-border text-muted-foreground hover:border-primary/50"
              }`}
            >
              {iso === "none" ? "なし" : "Worktree（独立コピー）"}
            </button>
          ))}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">
          worktree: リポジトリの独立コピーでエージェントを実行
        </p>
      </div>
    </div>
  );
}

// ─── プラグイン設定 ─────────────────────────────────────────

type BooleanPluginKeys = {
  [K in keyof import("@/types").PluginConfig]: import("@/types").PluginConfig[K] extends boolean
    ? K
    : never;
}[keyof import("@/types").PluginConfig];

function PluginConfig() {
  const {
    formData,
    togglePluginComponent,
    setPluginVersion,
    setPluginAuthor,
    setPluginKeywords,
  } = useWizardStore();
  const { pluginConfig } = formData;

  const components: { key: BooleanPluginKeys; label: string; desc: string }[] = [
    {
      key: "includeSkills",
      label: "スキル（SKILL.md）",
      desc: "スラッシュコマンドとして実行可能なスキル",
    },
    {
      key: "includeAgents",
      label: "エージェント（agent.md）",
      desc: "自律タスク実行用のサブエージェント",
    },
    {
      key: "includeHooks",
      label: "フック（hooks.json）",
      desc: "イベント駆動の自動処理",
    },
    {
      key: "includeClaudeMd",
      label: "CLAUDE.md",
      desc: "プロジェクトの永続的な指示書",
    },
    {
      key: "includeMcp",
      label: "MCP設定（.mcp.json）",
      desc: "外部ツール連携の設定",
    },
    {
      key: "includePluginJson",
      label: "plugin.json",
      desc: "プラグインのマニフェストファイル",
    },
    {
      key: "includeReadme",
      label: "README.md",
      desc: "プラグインの説明・使い方ドキュメント",
    },
  ];

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        プラグインに含めるコンポーネントを選択してください
      </p>
      {components.map(({ key, label, desc }) => (
        <div key={key} className="flex items-center justify-between rounded-lg border p-3">
          <div>
            <div className="text-sm font-medium">{label}</div>
            <div className="text-xs text-muted-foreground">{desc}</div>
          </div>
          <Switch
            checked={pluginConfig[key] as boolean}
            onCheckedChange={() => togglePluginComponent(key)}
          />
        </div>
      ))}

      {pluginConfig.includePluginJson && (
        <div className="space-y-3 rounded-lg border border-dashed p-3">
          <p className="text-xs font-medium text-muted-foreground">plugin.json メタデータ</p>
          <div>
            <Label htmlFor="plugin-version">バージョン</Label>
            <Input
              id="plugin-version"
              value={pluginConfig.pluginVersion}
              onChange={(e) => setPluginVersion(e.target.value)}
              placeholder="1.0.0"
              className="mt-1"
            />
          </div>
          <div>
            <Label htmlFor="plugin-author">作成者</Label>
            <Input
              id="plugin-author"
              value={pluginConfig.pluginAuthor}
              onChange={(e) => setPluginAuthor(e.target.value)}
              placeholder="Your Name"
              className="mt-1"
            />
          </div>
          <div>
            <Label htmlFor="plugin-keywords">キーワード</Label>
            <Input
              id="plugin-keywords"
              value={pluginConfig.pluginKeywords}
              onChange={(e) => setPluginKeywords(e.target.value)}
              placeholder="academic, research, review"
              className="mt-1"
            />
            <p className="mt-1 text-xs text-muted-foreground">カンマ区切り</p>
          </div>
        </div>
      )}
    </div>
  );
}
