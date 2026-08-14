import type { PaperGraph, PaperSummary } from "@/types";
import type { NodePosition } from "@/lib/graph/layout";

/**
 * 類似グラフの SVG 表示（REQ-GRAPH-005）。座標は lib/graph/layout が決定論で計算済み。
 * 色はデザイントークンのみを参照する（ADR-0026。種論文=シアン、選択=塗り、他は面なし）。
 */

interface GraphViewProps {
  graph: PaperGraph;
  positions: NodePosition[];
  selectedIds: ReadonlySet<string>;
  onToggle: (paper: PaperSummary) => void;
  /** ダブルクリックでこの論文を新しい種として再探索する（REQ-GRAPH-008） */
  onReseed: (paper: PaperSummary) => void;
  width: number;
  height: number;
}

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

export function GraphView({
  graph,
  positions,
  selectedIds,
  onToggle,
  onReseed,
  width,
  height,
}: GraphViewProps) {
  const positionOf = new Map(positions.map((p) => [p.id, p] as const));

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="h-full w-full"
      role="group"
      aria-label="論文の類似グラフ"
    >
      {graph.edges.map((edge) => {
        const source = positionOf.get(edge.source);
        const target = positionOf.get(edge.target);
        if (!source || !target) return null;
        return (
          <line
            key={`${edge.source}-${edge.target}`}
            x1={source.x}
            y1={source.y}
            x2={target.x}
            y2={target.y}
            stroke="hsl(var(--border))"
            strokeWidth={Math.min(edge.weight, 3)}
          />
        );
      })}
      {graph.nodes.map((node) => {
        const position = positionOf.get(node.paper.id);
        if (!position) return null;
        const selected = selectedIds.has(node.paper.id);
        return (
          <g
            key={node.paper.id}
            role="button"
            aria-label={node.paper.title}
            aria-pressed={selected}
            tabIndex={0}
            className="cursor-pointer"
            onClick={() => onToggle(node.paper)}
            onDoubleClick={() => onReseed(node.paper)}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onToggle(node.paper);
              }
            }}
          >
            {/* 円と題名の隙間でもクリックできるよう、透明のヒット領域を敷く */}
            <circle
              cx={position.x}
              cy={position.y + 6}
              r={node.isSeed ? 22 : 18}
              fill="transparent"
            />
            <circle
              cx={position.x}
              cy={position.y}
              r={node.isSeed ? 11 : 7}
              fill={selected ? "hsl(var(--signal))" : "hsl(var(--card))"}
              stroke={node.isSeed ? "hsl(var(--signal))" : "hsl(var(--muted-foreground))"}
              strokeWidth={node.isSeed ? 3 : 1.5}
            />
            <title>{node.paper.title}</title>
            <text
              x={position.x}
              y={position.y + (node.isSeed ? 26 : 20)}
              textAnchor="middle"
              className="pointer-events-none select-none"
              fontSize={10}
              fill="hsl(var(--muted-foreground))"
            >
              {truncate(node.paper.title, 24)}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
