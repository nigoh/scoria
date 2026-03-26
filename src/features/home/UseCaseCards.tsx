import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  MedicalIllustration,
  CSIllustration,
  SocialScienceIllustration,
  InterdisciplinaryIllustration,
} from "@/components/illustrations/UseCaseIllustrations";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

const useCases = [
  {
    Illustration: MedicalIllustration,
    title: "系統的文献レビュー",
    subtitle: "/systematic-review スキル",
    description:
      "PRISMA 2020準拠のスキルを生成。PICO分解、検索戦略策定、スクリーニング基準設定を一貫してサポートします。",
  },
  {
    Illustration: CSIllustration,
    title: "メタ分析支援",
    subtitle: "meta-analysis-agent エージェント",
    description:
      "効果量計算、異質性評価、分析コード生成を自律的に行うサブエージェントを作成します。",
  },
  {
    Illustration: SocialScienceIllustration,
    title: "引用チェック",
    subtitle: "/citation-check スキル",
    description:
      "論文の引用整合性を検証し、参考文献リストの完全性・書式一貫性を自動チェックするスキルを生成します。",
  },
  {
    Illustration: InterdisciplinaryIllustration,
    title: "プラグインパッケージ",
    subtitle: "スキル + エージェント + CLAUDE.md",
    description:
      "スキル・エージェント・フック・CLAUDE.mdを一括生成。研究プロジェクト全体をClaude Codeで加速します。",
  },
];

export function UseCaseCards() {
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
        ユースケース
      </h2>
      <div className="grid gap-6 sm:grid-cols-2">
        {useCases.map((uc) => (
          <Card
            key={uc.title}
            className="transition-colors hover:bg-muted/50"
          >
            <CardHeader>
              <div className="flex items-center gap-4">
                <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-xl bg-primary/5">
                  <uc.Illustration className="h-12 w-12" />
                </div>
                <div>
                  <CardTitle className="text-base">{uc.title}</CardTitle>
                  <CardDescription>{uc.subtitle}</CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">{uc.description}</p>
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  );
}
