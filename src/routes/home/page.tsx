import { Link } from "react-router-dom";
import { GithubLogoIcon } from "@phosphor-icons/react";
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
        <div className="mt-3 flex items-center justify-center gap-4">
          <Link to="/privacy" className="hover:text-foreground transition-colors">
            プライバシーポリシー
          </Link>
          <span aria-hidden="true">·</span>
          <Link to="/terms" className="hover:text-foreground transition-colors">
            利用規約
          </Link>
        </div>
        <p>Scoria — 学術研究プロンプト生成ツール</p>
        <p>
          Created by{" "}
          <a
            href="https://github.com/nigoh"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-foreground transition-colors underline underline-offset-4"
          >
            <GithubLogoIcon size={16} className="inline-block align-text-bottom" /> @nigoh
          </a>
        </p>
      </footer>
    </PageContainer>
  );
}
