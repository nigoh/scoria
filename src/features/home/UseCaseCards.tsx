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
    title: "医学系",
    subtitle: "PICOで先行研究を網羅的に探す",
    description:
      "PICO構造に基づいた系統的レビュー用プロンプトで、PubMed・Cochrane Libraryから網羅的に文献を収集します。",
  },
  {
    Illustration: CSIllustration,
    title: "情報科学",
    subtitle: "最新のLLM論文をarXivから探す",
    description:
      "arXiv・ACM DL・IEEE Xploreを対象に、大規模言語モデルの最新動向を効率的にサーベイするプロンプトを生成します。",
  },
  {
    Illustration: SocialScienceIllustration,
    title: "社会科学",
    subtitle: "質的研究のフレームワーク比較",
    description:
      "SPIDER構造を活用し、JSTOR・SSRN・SAGE Journalsから質的研究のフレームワークを体系的に比較します。",
  },
  {
    Illustration: InterdisciplinaryIllustration,
    title: "学際的",
    subtitle: "複数DBを横断した研究動向把握",
    description:
      "Google Scholar・Scopus・Web of Scienceを横断し、学際的な研究テーマのトレンドとギャップを発見します。",
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
