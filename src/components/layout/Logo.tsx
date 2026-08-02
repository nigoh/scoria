import { cn } from "@/lib/utils";

interface LogoProps {
  className?: string;
}

/**
 * ワードマーク（ADR-0026）。
 *
 * 以前は明暗2枚の SVG で、どちらも Google Fonts を @import していた（実際には読み込まれず
 * フォールバックしていた）。等幅を既定に据えた以上、本文と同じ書体で組むのが素直なので
 * インライン化した。テーマ切替でも色はトークン任せで追従する。
 */
export function Logo({ className }: LogoProps) {
  return (
    <span
      className={cn("inline-flex items-baseline text-lg font-bold tracking-tight", className)}
      aria-label="Scoria"
    >
      <span aria-hidden="true" className="text-primary">
        ▍
      </span>
      <span aria-hidden="true" className="text-foreground">
        scoria
      </span>
    </span>
  );
}
