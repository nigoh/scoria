import { cn } from "@/lib/utils";
import type { WizardStep } from "@/types";
import { WIZARD_STEP_LABELS } from "@/lib/constants";

interface WizardProgressProps {
  currentStep: WizardStep;
}

const STEPS: WizardStep[] = [1, 2, 3, 4];

/**
 * ステップ表示（ADR-0026）。
 *
 * 丸バッジ＋ラベルの横並びは幅に耐えず「拡張タイ／プ」のように折り返して崩れていた。
 * 4等分すると今度はラベルが省略されるので、**ラベルは現在のステップにだけ**出し、
 * その区画だけを伸ばす。他は `[n/4]` の固定幅で置く。どの幅でも省略記号が出ない。
 */
export function WizardProgress({ currentStep }: WizardProgressProps) {
  return (
    <ol className="flex min-w-0 flex-1 items-stretch border border-border" aria-label="進捗">
      {STEPS.map((step) => {
        const isDone = step < currentStep;
        const isCurrent = step === currentStep;
        return (
          <li
            key={step}
            aria-current={isCurrent ? "step" : undefined}
            className={cn(
              "flex items-baseline gap-1.5 whitespace-nowrap px-2 py-1.5 text-xs",
              "border-r border-border last:border-r-0",
              // 琥珀の塗りは主アクション（次へ / ZIP ダウンロード）に取っておく。
              // 現在地は下線と番号の色で示し、面は塗らない（ADR-0026）
              isCurrent &&
                "min-w-0 flex-1 bg-secondary font-bold text-foreground shadow-[inset_0_-2px_0_hsl(var(--primary))]",
              isDone && !isCurrent && "shrink-0 text-signal",
              !isDone && !isCurrent && "shrink-0 text-muted-foreground",
            )}
          >
            <span className={cn("shrink-0 tabular-nums", isCurrent && "text-primary")}>
              [{isDone ? "✓" : step}/{STEPS.length}]
            </span>
            {isCurrent && <span className="truncate font-sans">{WIZARD_STEP_LABELS[step]}</span>}
            {/* 完了・未着手のステップ名は読み上げには残す（視覚的には番号だけ） */}
            {!isCurrent && <span className="sr-only">{WIZARD_STEP_LABELS[step]}</span>}
          </li>
        );
      })}
    </ol>
  );
}
