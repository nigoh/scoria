/**
 * ヒーローの右側（ADR-0026）。
 *
 * 抽象的なイラストではなく、Scoria が実際に吐くファイルをそのまま置く。
 * 「何が手に入るのか」を説明文より先に見せるのが、この方向でのヒーローの役目。
 */

interface Line {
  no: number;
  /** そのまま出す本文（キーと値に分けないもの） */
  text?: string;
  /** frontmatter のキー */
  key?: string;
  /** frontmatter の値 */
  value?: string;
  /** Markdown の見出し */
  heading?: string;
}

const LINES: Line[] = [
  { no: 1, text: "---" },
  { no: 2, key: "name", value: "repro-review" },
  { no: 3, key: "description", value: "研究コードを再現性の観点でレビューする" },
  { no: 4, key: "allowed-tools", value: "Read, Grep, Glob, Bash" },
  { no: 5, key: "model", value: "sonnet" },
  { no: 6, text: "---" },
  { no: 7, text: "" },
  { no: 8, heading: "## タスク指示" },
  { no: 9, text: "乱数シード・環境固定・データ来歴の観点で" },
  { no: 10, text: "変更差分をレビューする。" },
];

export function HeroTerminal() {
  return (
    <figure className="m-0 border border-border bg-card">
      <figcaption className="flex items-center justify-between border-b border-border px-3 py-2 text-xs">
        <span className="truncate text-signal">.claude/skills/repro-review/SKILL.md</span>
        <span className="shrink-0 text-muted-foreground">生成物</span>
      </figcaption>
      <pre className="overflow-x-auto p-3 text-xs leading-relaxed">
        <code>
          {LINES.map((line) => (
            <span key={line.no} className="flex gap-3">
              <span className="w-4 shrink-0 select-none text-right tabular-nums text-muted-foreground/60">
                {line.no}
              </span>
              <span className="min-w-0">
                {line.key ? (
                  <>
                    <span className="text-signal">{line.key}</span>
                    <span className="text-muted-foreground">: </span>
                    <span className="text-primary">{line.value}</span>
                  </>
                ) : line.heading ? (
                  <span className="font-bold text-foreground">{line.heading}</span>
                ) : (
                  <span className="text-muted-foreground">{line.text}</span>
                )}
              </span>
            </span>
          ))}
        </code>
      </pre>
    </figure>
  );
}
