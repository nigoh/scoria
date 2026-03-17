import {
  Compass,
  TextAlignLeft,
  Lightning,
  CopySimple,
} from "@phosphor-icons/react";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

const steps = [
  {
    icon: Compass,
    title: "研究フェーズを選ぶ",
    description: "テーマ設定・先行研究・仮説構築・方法論設計から選択",
  },
  {
    icon: TextAlignLeft,
    title: "研究コンテキストを入力",
    description: "分野・キーワード・目的・対象DBを段階的に入力",
  },
  {
    icon: Lightning,
    title: "プロンプトを生成・改善",
    description: "AIが最適なプロンプトを自動生成、改善提案も表示",
  },
  {
    icon: CopySimple,
    title: "コピーして活用",
    description: "Claude・ChatGPT・Perplexity等にそのまま貼り付け",
  },
];

function StepConnector() {
  return (
    <svg
      className="hidden h-0.5 w-10 lg:block"
      viewBox="0 0 40 2"
      aria-hidden="true"
    >
      <line
        x1="0"
        y1="1"
        x2="40"
        y2="1"
        stroke="currentColor"
        strokeWidth="2"
        strokeDasharray="4 4"
        className="animate-dash-flow text-border"
      />
    </svg>
  );
}

export function StepFlow() {
  const { ref, inView } = useInView();

  return (
    <section
      ref={ref}
      className={cn(
        "py-16 transition-all duration-700",
        inView ? "animate-fade-in-up" : "opacity-0",
      )}
    >
      <h2 className="mb-12 text-center text-2xl font-semibold text-foreground">
        使い方
      </h2>
      <div className="flex flex-col items-center gap-8 sm:flex-row sm:flex-wrap sm:justify-center lg:flex-nowrap lg:gap-0">
        {steps.map((step, i) => (
          <div key={i} className="flex items-center gap-0">
            <div className="flex w-48 flex-col items-center text-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10 text-primary">
                <step.icon size={28} />
              </div>
              <div className="mt-2 flex h-6 w-6 items-center justify-center rounded-full bg-muted text-xs font-bold text-muted-foreground">
                {i + 1}
              </div>
              <h3 className="mt-3 text-base font-semibold text-foreground">
                {step.title}
              </h3>
              <p className="mt-1 text-sm text-muted-foreground">
                {step.description}
              </p>
            </div>
            {i < steps.length - 1 && <StepConnector />}
          </div>
        ))}
      </div>
    </section>
  );
}
