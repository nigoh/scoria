import { cn } from "@/lib/utils";
import { useWizardStore } from "@/stores/wizardStore";
import { EXTENSION_TYPES } from "@/lib/constants";
import type { ExtensionType } from "@/types";
import { StepHeading } from "../StepHeading";

/**
 * 拡張タイプごとの出力先。何を選ぶと何が出てくるかを、選ぶ画面で見せる（ADR-0026）。
 * 実際の生成パスは lib/generator.ts が持つ正本で、ここはその案内。
 */
const OUTPUT_PATH: Record<ExtensionType, string> = {
  skill: ".claude/skills/<name>/SKILL.md",
  agent: ".claude/agents/<name>.md",
  plugin: ".claude-plugin/plugin.json + skills/ + agents/",
};

export function Step1ExtensionType() {
  const { formData, setExtensionType } = useWizardStore();

  return (
    <div className="space-y-4">
      <StepHeading
        title="拡張タイプを選択"
        hint="つくる Claude Code 拡張の種類を1つ選んでください。"
      />
      <div className="flex flex-col gap-px bg-border">
        {EXTENSION_TYPES.map((ext) => {
          const isSelected = formData.extensionType === ext.id;
          return (
            <button
              key={ext.id}
              type="button"
              aria-pressed={isSelected}
              onClick={() => setExtensionType(ext.id as ExtensionType)}
              className={cn(
                "flex items-start gap-3 border-l-2 bg-card px-3 py-3 text-left transition-colors",
                "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring",
                isSelected
                  ? "border-l-primary bg-accent"
                  : "border-l-transparent hover:bg-accent/60",
              )}
            >
              <span
                className={cn(
                  "mt-0.5 shrink-0 select-none text-sm",
                  isSelected ? "text-primary" : "text-muted-foreground",
                )}
                aria-hidden="true"
              >
                {isSelected ? "▸" : "·"}
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-bold">{ext.labelJa}</span>
                <span className="mt-0.5 block truncate text-xs text-signal">
                  {OUTPUT_PATH[ext.id]}
                </span>
                <span className="mt-1.5 block font-sans text-xs leading-relaxed text-muted-foreground">
                  {ext.descriptionJa}
                </span>
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
