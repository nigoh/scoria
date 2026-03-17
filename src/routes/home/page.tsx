import { PageContainer } from "@/components/layout/PageContainer";
import { HeroSection } from "@/features/home/HeroSection";
import { StepFlow } from "@/features/home/StepFlow";
import { UseCaseCards } from "@/features/home/UseCaseCards";
import { TutorialCTA } from "@/features/home/TutorialCTA";

export function Component() {
  return (
    <PageContainer>
      <HeroSection />
      <StepFlow />
      <UseCaseCards />
      <TutorialCTA />
      <footer className="mt-16 border-t border-border py-8 text-center text-sm text-muted-foreground">
        Scoria — 学術研究プロンプト生成ツール
      </footer>
    </PageContainer>
  );
}
