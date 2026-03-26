import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useWizardStore } from "@/stores/wizardStore";
import { CLAUDE_TOOLS, MODEL_OPTIONS, RESEARCH_FIELDS } from "@/lib/constants";
import type { ModelChoice } from "@/types";

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

      {formData.extensionType === "skill" && <SkillConfig />}
      {formData.extensionType === "agent" && <AgentConfig />}
      {formData.extensionType === "plugin" && <PluginConfig />}
    </div>
  );
}

function SkillConfig() {
  const {
    formData,
    setSkillArgumentHint,
    setSkillAllowedTools,
    setSkillModel,
    setSkillUserInvocable,
  } = useWizardStore();
  const { skillConfig } = formData;

  return (
    <div className="space-y-4">
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

function AgentConfig() {
  const { formData, setAgentTools, setAgentModel, setAgentMaxTurns, setAgentResearchField } =
    useWizardStore();
  const { agentConfig } = formData;

  return (
    <div className="space-y-4">
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

function PluginConfig() {
  const { formData, togglePluginComponent } = useWizardStore();
  const { pluginConfig } = formData;

  const components: { key: keyof typeof pluginConfig; label: string; desc: string }[] = [
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
            checked={pluginConfig[key]}
            onCheckedChange={() => togglePluginComponent(key)}
          />
        </div>
      ))}
    </div>
  );
}
