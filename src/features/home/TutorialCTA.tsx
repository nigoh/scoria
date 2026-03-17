import { Link } from "react-router-dom";
import { RocketLaunch } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

export function TutorialCTA() {
  const { ref, inView } = useInView();

  return (
    <section
      ref={ref}
      className={cn(
        "rounded-xl border border-border bg-muted/30 px-8 py-12 text-center transition-all duration-700",
        inView ? "animate-fade-in-up" : "opacity-0",
      )}
    >
      <RocketLaunch size={40} className="mx-auto text-primary" />
      <h2 className="mt-4 text-xl font-semibold text-foreground">
        はじめての Scoria
      </h2>
      <p className="mx-auto mt-2 max-w-md text-sm text-muted-foreground">
        ビルダー画面で研究フェーズを選び、5ステップのウィザードに沿って入力するだけ。
        初めてでも迷わずプロンプトを作成できます。
      </p>
      <Button asChild variant="outline" className="mt-6">
        <Link to="/builder">使い方を試す</Link>
      </Button>
    </section>
  );
}
