import {
  Command,
  Sliders,
  Lightning,
  DownloadSimple,
} from "@phosphor-icons/react";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

const steps = [
  {
    Icon: Command,
    title: "拡張タイプを選択",
    description:
      "スキル（Slash Command）、エージェント、またはプラグインパッケージから選択します。",
  },
  {
    Icon: Sliders,
    title: "テンプレート & 設定",
    description:
      "学術テンプレートを選び、名前・ツール・モデルなどの詳細を設定します。",
  },
  {
    Icon: Lightning,
    title: "拡張を生成",
    description:
      "設定をもとに、SKILL.md・agent.md・CLAUDE.md などのファイルを自動生成します。",
  },
  {
    Icon: DownloadSimple,
    title: "ZIPでダウンロード",
    description:
      "生成ファイルをZIPでダウンロードし、.claude/ ディレクトリに配置するだけで利用開始できます。",
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
