import { Check } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import type { WizardStep } from "@/types";

const stepLabels: Record<WizardStep, string> = {
  1: "研究フェーズ",
  2: "研究分野",
  3: "キーワード",
  4: "研究目的",
  5: "詳細条件",
};

interface WizardProgressProps {
  currentStep: WizardStep;
}

export function WizardProgress({ currentStep }: WizardProgressProps) {
  return (
    <div className="flex items-center gap-1">
      {([1, 2, 3, 4, 5] as WizardStep[]).map((step, i) => {
        const isCompleted = step < currentStep;
        const isCurrent = step === currentStep;
        return (
          <div key={step} className="flex items-center gap-1">
            {i > 0 && (
              <div
                className={cn(
                  "h-px w-6",
                  isCompleted ? "bg-primary" : "bg-border",
                )}
              />
            )}
            <div
              className={cn(
                "flex h-7 w-7 items-center justify-center rounded-full text-xs font-medium transition-colors",
                isCompleted && "bg-primary text-primary-foreground",
                isCurrent && "border-2 border-primary text-primary",
                !isCompleted && !isCurrent && "border border-border text-muted-foreground",
              )}
            >
              {isCompleted ? <Check size={14} weight="bold" /> : step}
            </div>
            <span
              className={cn(
                "hidden text-xs sm:inline",
                isCurrent ? "font-medium text-foreground" : "text-muted-foreground",
              )}
            >
              {stepLabels[step]}
            </span>
          </div>
        );
      })}
    </div>
  );
}
