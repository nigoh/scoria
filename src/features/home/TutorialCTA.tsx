import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { TutorialIllustration } from "@/components/illustrations/TutorialIllustration";
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
      <TutorialIllustration className="mx-auto h-40 w-auto" />
      <h2 className="mt-4 text-xl font-semibold text-foreground">
        はじめての Scoria
      </h2>
      <p className="mx-auto mt-2 max-w-md text-sm text-muted-foreground">
        拡張タイプを選び、4ステップのウィザードに沿って設定するだけ。
        学術研究に特化したClaude Code拡張を簡単に作成できます。
      </p>
      <Button asChild variant="outline" className="mt-6">
        <Link to="/builder">拡張を作成する</Link>
      </Button>
    </section>
  );
}
