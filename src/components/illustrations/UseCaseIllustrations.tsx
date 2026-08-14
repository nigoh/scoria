import { useIllustrationColors } from "@/lib/useIllustrationColors";

interface Props {
  className?: string;
}

/**
 * ユースケースカードのイラスト（ADR-0030 の RSE ユースケースに対応）。
 * 色は useIllustrationColors 経由でテーマトークンから取り、直書きしない（ADR-0026）。
 */

/** 再現性レビュー: 2つの実行が同じ出力になる（=）ことを表す */
export function ReproIllustration({ className }: Props) {
  const c = useIllustrationColors();
  return (
    <svg
      viewBox="0 0 100 86"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      {[14, 58].map((x) => (
        <g key={x}>
          <rect x={x} y="18" width="28" height="34" rx="2" fill={c.accentLt} />
          <rect x={x + 4} y="24" width="20" height="2.5" rx="1.25" fill={c.accent} opacity="0.6" />
          <rect x={x + 4} y="31" width="14" height="2.5" rx="1.25" fill={c.accent} opacity="0.4" />
          <rect x={x + 4} y="38" width="18" height="2.5" rx="1.25" fill={c.accent} opacity="0.5" />
          <rect x={x + 4} y="45" width="10" height="2.5" rx="1.25" fill={c.accent} opacity="0.3" />
        </g>
      ))}
      <path
        d="M46,31 L54,31 M46,39 L54,39"
        stroke={c.accent}
        strokeWidth="3"
        strokeLinecap="round"
      />
      <text
        x="50"
        y="72"
        textAnchor="middle"
        fontSize="8"
        fill={c.accent}
        opacity="0.6"
        fontFamily="monospace"
        fontWeight="700"
      >
        seed=42
      </text>
    </svg>
  );
}

/** 数値テスト設計: 許容誤差バンドの中に測定点が収まる */
export function SciTestIllustration({ className }: Props) {
  const c = useIllustrationColors();
  return (
    <svg
      viewBox="0 0 100 86"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <path d="M16,14 L16,66 L88,66" stroke={c.g1} strokeWidth="2" strokeLinecap="round" />
      {/* 許容誤差バンド */}
      <path
        d="M16,42 C36,26 60,26 86,34 L86,46 C60,38 36,38 16,54 Z"
        fill={c.accent}
        opacity="0.12"
      />
      <path
        d="M16,48 C36,32 60,32 86,40"
        stroke={c.accent}
        strokeWidth="2"
        strokeLinecap="round"
        opacity="0.7"
      />
      {[
        [28, 41],
        [44, 35],
        [62, 34],
        [78, 38],
      ].map(([cx, cy]) => (
        <circle key={cx} cx={cx} cy={cy} r="3" fill={c.accent} />
      ))}
      <text
        x="70"
        y="22"
        fontSize="8"
        fill={c.accent}
        opacity="0.6"
        fontFamily="monospace"
        fontWeight="700"
      >
        ±tol
      </text>
    </svg>
  );
}

/** リリース・DOI: バージョンタグと DOI ラベル */
export function ReleaseIllustration({ className }: Props) {
  const c = useIllustrationColors();
  const fg = c.bg === "#ffffff" ? "#fff" : "#000";
  return (
    <svg
      viewBox="0 0 100 86"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      {/* タグ形 */}
      <path d="M22,22 L52,22 L66,36 L52,50 L22,50 Z" fill={c.accentLt} />
      <circle cx="30" cy="36" r="3.5" fill={c.accent} opacity="0.6" />
      <text x="39" y="39" fontSize="9" fill={c.accent} fontFamily="monospace" fontWeight="700">
        v1.2
      </text>
      {/* DOI バッジ */}
      <rect x="40" y="58" width="24" height="14" rx="2" fill={c.accent} opacity="0.85" />
      <text
        x="52"
        y="68"
        textAnchor="middle"
        fontSize="8"
        fill={fg}
        fontFamily="monospace"
        fontWeight="700"
      >
        DOI
      </text>
      <rect x="66" y="58" width="18" height="14" rx="2" fill={c.g1} />
      <rect x="69" y="63" width="12" height="2" rx="1" fill={c.accent} opacity="0.4" />
      <rect x="69" y="67" width="8" height="2" rx="1" fill={c.accent} opacity="0.25" />
    </svg>
  );
}

/** プラグインパッケージ: スキル・エージェント・設定を束ねた箱 */
export function PluginIllustration({ className }: Props) {
  const c = useIllustrationColors();
  return (
    <svg
      viewBox="0 0 100 86"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <path d="M50,10 L78,22 L78,52 L50,64 L22,52 L22,22 Z" fill={c.accent} opacity="0.1" />
      <path d="M50,10 L78,22 L50,34 L22,22 Z" fill={c.accent} opacity="0.2" />
      <path d="M50,34 L50,64" stroke={c.accent} strokeWidth="1.2" opacity="0.3" />
      <path
        d="M22,22 L22,52 L50,64"
        stroke={c.accent}
        strokeWidth="1.2"
        opacity="0.2"
        fill="none"
      />
      <path
        d="M78,22 L78,52 L50,64"
        stroke={c.accent}
        strokeWidth="1.2"
        opacity="0.2"
        fill="none"
      />
      {[0, 1, 2].map((i) => (
        <rect
          key={i}
          x={20 + i * 22}
          y={70}
          width={18}
          height={8}
          rx={2}
          fill={c.accent}
          opacity={0.4 - i * 0.1}
        />
      ))}
    </svg>
  );
}
