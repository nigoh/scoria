import { Link } from "react-router-dom";
import { Graph } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { useInView } from "@/lib/useInView";
import { cn } from "@/lib/utils";

/** ランディングの論文グラフ探索の紹介（ADR-0028）。SVG は決定論の飾りグラフ */
export function GraphIntro() {
  const { ref, inView } = useInView();

  const nodes = [
    { x: 150, y: 70, r: 11, seed: true },
    { x: 60, y: 40, r: 6, seed: false },
    { x: 55, y: 110, r: 7, seed: false },
    { x: 235, y: 45, r: 6, seed: false },
    { x: 250, y: 105, r: 7, seed: false },
    { x: 150, y: 20, r: 5, seed: false },
  ];

  return (
    <section
      ref={ref}
      className={cn(
        "mt-16 border border-border bg-card transition-all duration-700 md:flex",
        inView ? "animate-fade-in-up" : "opacity-0",
      )}
    >
      <div className="flex items-center justify-center border-b border-border p-6 md:w-80 md:border-b-0 md:border-r">
        <svg viewBox="0 0 300 140" className="h-32 w-auto" aria-hidden="true">
          {nodes.slice(1).map((n, i) => (
            <line
              key={`edge-${i}`}
              x1={nodes[0].x}
              y1={nodes[0].y}
              x2={n.x}
              y2={n.y}
              stroke="hsl(var(--border))"
              strokeWidth={i % 2 === 0 ? 2 : 1}
            />
          ))}
          {nodes.map((n, i) => (
            <circle
              key={`node-${i}`}
              cx={n.x}
              cy={n.y}
              r={n.r}
              fill={n.seed ? "hsl(var(--signal))" : "hsl(var(--card))"}
              stroke={n.seed ? "hsl(var(--signal))" : "hsl(var(--muted-foreground))"}
              strokeWidth={1.5}
            />
          ))}
        </svg>
      </div>
      <div className="flex-1 px-8 py-10">
        <h2 className="flex items-center gap-2 text-xl font-semibold text-foreground">
          <Graph size={22} />
          論文グラフ探索
        </h2>
        <p className="mt-2 max-w-lg font-sans text-sm text-muted-foreground">
          キーワードや DOI から種論文を選ぶと、引用関係（書誌結合・共引用）の近さで
          関連論文がグラフに広がります。たどって組んだ手法論文のリストは、それを実装する
          研究ソフトウェア拡張の AI 設計に根拠として渡せます。データは
          OpenAlex（CC0）、登録不要です。
        </p>
        <Button asChild variant="outline" className="mt-6">
          <Link to="/graph">論文グラフを開く</Link>
        </Button>
      </div>
    </section>
  );
}
