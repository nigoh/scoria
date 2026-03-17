import {
  Compass,
  Books,
  Lightbulb,
  Flask,
} from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import { useWizardStore } from "@/stores/wizardStore";
import { RESEARCH_PHASES } from "@/lib/constants";
import type { ResearchPhase } from "@/types";

const iconMap: Record<string, React.ComponentType<{ size?: number }>> = {
  Compass,
  Books,
  Lightbulb,
  FlaskConical: Flask,
};

export function Step1ResearchPhase() {
  const { formData, setPhase } = useWizardStore();

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-foreground">
          研究フェーズを選択
        </h3>
        <p className="mt-1 text-sm text-muted-foreground">
          現在の研究段階に合ったプロンプトを生成します
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        {RESEARCH_PHASES.map((phase) => {
          const Icon = iconMap[phase.icon] ?? Compass;
          const isSelected = formData.phase === phase.id;
          return (
            <button
              key={phase.id}
              type="button"
              onClick={() => setPhase(phase.id as ResearchPhase)}
              className={cn(
                "flex flex-col items-start gap-2 rounded-lg border p-4 text-left transition-colors",
                isSelected
                  ? "border-primary bg-primary/5 ring-2 ring-primary/20"
                  : "border-border hover:bg-muted/50",
              )}
            >
              <div className="flex items-center gap-2">
                <Icon size={20} />
                <span className="font-medium text-foreground">
                  {phase.labelJa}
                </span>
              </div>
              <p className="text-xs text-muted-foreground">
                {phase.descriptionJa}
              </p>
            </button>
          );
        })}
      </div>
    </div>
  );
}
