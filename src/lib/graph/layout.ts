import type { PaperGraph } from "@/types";

/**
 * 決定論の力学レイアウト（REQ-GRAPH-005 の表示基盤）。
 *
 * Fruchterman-Reingold 型の反発＋引力を固定回数だけ反復する。乱数を使わず
 * 初期配置は円周上に等間隔で置くため、同一入力なら常に同一のレイアウトになる。
 * 種論文は中央に固定する。React にも DOM にも依存しない純粋関数。
 */

export const LAYOUT_PADDING = 48;
const ITERATIONS = 150;

export interface NodePosition {
  id: string;
  x: number;
  y: number;
}

export function layoutGraph(graph: PaperGraph, width: number, height: number): NodePosition[] {
  const nodes = graph.nodes;
  const centerX = width / 2;
  const centerY = height / 2;
  if (nodes.length === 0) return [];

  const seedIndex = Math.max(
    0,
    nodes.findIndex((n) => n.isSeed),
  );
  const xs = new Array<number>(nodes.length);
  const ys = new Array<number>(nodes.length);

  // 初期配置: 種は中央、他は円周上に等間隔（決定論）
  const radius = Math.min(width, height) / 3;
  let ringIndex = 0;
  const ringCount = Math.max(1, nodes.length - 1);
  for (let i = 0; i < nodes.length; i += 1) {
    if (i === seedIndex) {
      xs[i] = centerX;
      ys[i] = centerY;
      continue;
    }
    const angle = (2 * Math.PI * ringIndex) / ringCount;
    xs[i] = centerX + radius * Math.cos(angle);
    ys[i] = centerY + radius * Math.sin(angle);
    ringIndex += 1;
  }
  if (nodes.length === 1) return [{ id: nodes[0].paper.id, x: centerX, y: centerY }];

  const indexOf = new Map(nodes.map((n, i) => [n.paper.id, i] as const));
  // ノードが少ないとき理想距離が画面を超えて全ノードが境界に張り付くため、上限を掛ける
  const k = Math.min(Math.sqrt((width * height) / nodes.length), Math.min(width, height) / 4);

  for (let iter = 0; iter < ITERATIONS; iter += 1) {
    const dxs = new Array<number>(nodes.length).fill(0);
    const dys = new Array<number>(nodes.length).fill(0);

    // 反発（全ペア）
    for (let i = 0; i < nodes.length; i += 1) {
      for (let j = i + 1; j < nodes.length; j += 1) {
        let dx = xs[i] - xs[j];
        let dy = ys[i] - ys[j];
        if (dx === 0 && dy === 0) {
          // 完全に重なったペアは決定論の微小ずらしで分離する
          dx = 0.01 * (i - j);
          dy = 0.01;
        }
        const dist = Math.sqrt(dx * dx + dy * dy);
        const force = (k * k) / dist / dist;
        dxs[i] += dx * force;
        dys[i] += dy * force;
        dxs[j] -= dx * force;
        dys[j] -= dy * force;
      }
    }

    // 引力（エッジ）
    for (const edge of graph.edges) {
      const i = indexOf.get(edge.source);
      const j = indexOf.get(edge.target);
      if (i === undefined || j === undefined) continue;
      const dx = xs[i] - xs[j];
      const dy = ys[i] - ys[j];
      const dist = Math.sqrt(dx * dx + dy * dy) || 0.01;
      const force = dist / k;
      dxs[i] -= dx * force;
      dys[i] -= dy * force;
      dxs[j] += dx * force;
      dys[j] += dy * force;
    }

    // 冷却しながら移動し、境界の内側にクランプする
    const temperature = (0.1 * Math.min(width, height) * (ITERATIONS - iter)) / ITERATIONS;
    for (let i = 0; i < nodes.length; i += 1) {
      if (i === seedIndex) continue;
      const move = Math.sqrt(dxs[i] * dxs[i] + dys[i] * dys[i]);
      if (move === 0) continue;
      const capped = Math.min(move, temperature);
      xs[i] += (dxs[i] / move) * capped;
      ys[i] += (dys[i] / move) * capped;
      xs[i] = Math.min(width - LAYOUT_PADDING, Math.max(LAYOUT_PADDING, xs[i]));
      ys[i] = Math.min(height - LAYOUT_PADDING, Math.max(LAYOUT_PADDING, ys[i]));
    }
  }

  return nodes.map((n, i) => ({ id: n.paper.id, x: xs[i], y: ys[i] }));
}
