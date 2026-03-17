import { Link } from "react-router-dom";
import { ArrowRight } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { HeroIllustration } from "@/components/illustrations/HeroIllustration";
import { HeroBackground } from "./HeroBackground";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

export function HeroSection() {
  const { ref, inView } = useInView(0.1);

  return (
    <section ref={ref} className="relative py-20">
      <HeroBackground />
      <div
        className={cn(
          "relative z-10 grid items-center gap-12 md:grid-cols-2",
          inView ? "animate-fade-in-up" : "opacity-0",
        )}
      >
        <div className="text-center md:text-left">
          <h1 className="text-4xl font-bold leading-tight tracking-tight text-foreground sm:text-5xl">
            学術検索のプロンプトを、構造的につくる
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground">
            研究テーマや目的を入力するだけで、学術検索や文献レビューに最適な
            AIプロンプトを自動生成。あなたの研究フェーズに合わせた高品質なプロンプトで、
            AIの力を最大限に引き出します。
          </p>
          <div className="mt-10">
            <Button asChild size="lg" className="gap-2 text-base">
              <Link to="/builder">
                プロンプトを作成する
                <ArrowRight size={20} />
              </Link>
            </Button>
          </div>
        </div>
        <div className="hidden md:flex md:items-center md:justify-center">
          <HeroIllustration className="h-auto w-full max-w-sm" />
        </div>
      </div>
    </section>
  );
}
