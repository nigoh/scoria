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
    Icon: Compass,
    title: "テーマを設定",
    description:
      "研究フェーズ（探索・深掘り・系統的レビューなど）と専門分野を選択します。",
  },
  {
    Icon: TextAlignLeft,
    title: "詳細を入力",
    description:
      "キーワード・研究目的・対象データベースなどの条件をウィザード形式で入力します。",
  },
  {
    Icon: Lightning,
    title: "プロンプト生成",
    description:
      "入力内容をもとに、学術検索に最適化された構造的プロンプトを自動で組み立てます。",
  },
  {
    Icon: CopySimple,
    title: "コピーして活用",
    description:
      "生成されたプロンプトをコピーし、ChatGPTやClaudeなどのAIに貼り付けて文献検索を開始できます。",
  },
];

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
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {steps.map((step, i) => (
          <div key={step.title} className="flex flex-col items-center text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-primary/10">
              <step.Icon size={28} weight="duotone" className="text-primary" />
            </div>
            <span className="mt-1 text-xs font-medium text-primary">
              Step {i + 1}
            </span>
            <h3 className="mt-2 text-base font-semibold text-foreground">
              {step.title}
            </h3>
            <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
              {step.description}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}
