import {
  Compass,
  TextAlignLeft,
  Lightning,
  CopySimple,
} from "@phosphor-icons/react";

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

export function StepFlow() {
  return (
    <section className="py-16">
      <h2 className="mb-12 text-center text-2xl font-semibold text-foreground">
        使い方
      </h2>
      <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
        {steps.map((step, i) => (
          <div key={i} className="flex flex-col items-center text-center">
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
        ))}
      </div>
    </section>
  );
}
