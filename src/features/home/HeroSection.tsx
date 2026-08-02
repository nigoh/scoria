import { Link } from "react-router-dom";
import { ArrowRight } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { HeroBackground } from "./HeroBackground";
import { HeroTerminal } from "./HeroTerminal";
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
        <div>
          <p className="mb-5 flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
            <span className="text-primary">$</span>
            <span className="text-signal">scoria</span>
            <span>new skill --template systematic-review</span>
          </p>
          {/* 見出しだけ和文ゴシックにする。等幅の和文フォールバックは字送りが緩く、
              大きな級数では締まりが出ない（ADR-0026 の混植方針） */}
          <h1 className="text-balance font-sans text-4xl font-bold leading-tight tracking-tight text-foreground sm:text-5xl">
            学術研究のための Claude Code 拡張をつくる
          </h1>
          <p className="mt-6 max-w-xl font-sans text-base leading-relaxed text-muted-foreground">
            系統的レビュー、メタ分析、引用チェック。研究の手順をスキル・エージェント・プラグインに落とし、
            ZIP かコマンド1行で手元のリポジトリに置けます。
          </p>
          <div className="mt-9 flex flex-wrap items-center gap-4">
            <Button asChild size="lg" className="gap-2">
              <Link to="/builder">
                拡張をつくる
                <ArrowRight size={18} />
              </Link>
            </Button>
            <span className="font-sans text-xs text-muted-foreground">
              登録不要・ブラウザ内で完結
            </span>
          </div>
        </div>
        <div className="hidden md:block">
          <HeroTerminal />
        </div>
      </div>
    </section>
  );
}
