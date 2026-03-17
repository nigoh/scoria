import { Link } from "react-router-dom";
import { ArrowRight } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { HeroBackground } from "./HeroBackground";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

export function HeroSection() {
  const { ref, inView } = useInView(0.1);

  return (
    <section ref={ref} className="relative py-24 text-center">
      <HeroBackground />
      <div
        className={cn(
          "relative z-10 transition-all duration-700",
          inView ? "animate-fade-in-up" : "opacity-0",
        )}
      >
        <h1 className="text-4xl font-bold leading-tight tracking-tight text-foreground sm:text-5xl">
          学術検索のプロンプトを、構造的につくる
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-muted-foreground">
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
    </section>
  );
}
