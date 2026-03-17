import { Link } from "react-router-dom";
import { ArrowRight } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";

export function HeroSection() {
  return (
    <section className="py-24 text-center">
      <h1 className="text-4xl font-bold leading-tight tracking-tight text-foreground sm:text-5xl">
        知の地層から、最適な問いを掘り出す
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
    </section>
  );
}
