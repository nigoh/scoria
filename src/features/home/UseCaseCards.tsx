import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
    Illustration: CSIllustration,
    title: "再現性コードレビュー",
    subtitle: "/repro-review スキル",
    description:
      "乱数シード・環境固定・データ来歴の観点で解析コードをレビュー。第三者が再現するための最小作業も洗い出します。",
  },
  {
    Illustration: MedicalIllustration,
    title: "数値コードのテスト設計",
    subtitle: "sci-test-agent エージェント",
    description:
      "許容誤差・性質ベース・ゴールデンデータの3層で、数値・データ処理コードのテストを設計・実装します。",
  },
  {
    Illustration: SocialScienceIllustration,
    title: "リリース・DOI アーカイブ",
    subtitle: "/release-doi スキル",
    description:
      "バージョン判定・CHANGELOG・CITATION.cff の更新から DOI 発行メタデータまで、引用可能なリリースを準備します。",
  },
  {
    Illustration: InterdisciplinaryIllustration,
    title: "プラグインパッケージ",
    subtitle: "スキル + エージェント + CLAUDE.md",
    description:
      "スキル・エージェント・フック・CLAUDE.mdを一括生成。研究ソフトのリポジトリ全体をClaude Codeで加速します。",
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
      <h2 className="mb-10 flex items-baseline gap-2 text-xl font-bold text-foreground">
        <span className="text-primary" aria-hidden="true">
          ▍
        </span>
        ユースケース
      </h2>
      <div className="grid gap-6 sm:grid-cols-2">
        {useCases.map((uc) => (
          <Card key={uc.title} className="transition-colors hover:bg-muted/50">
            <CardHeader>
              <div className="flex items-center gap-4">
                <div className="flex h-16 w-16 shrink-0 items-center justify-center border border-border bg-secondary">
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
