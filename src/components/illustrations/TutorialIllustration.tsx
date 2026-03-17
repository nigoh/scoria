import { useIllustrationColors } from "@/lib/useIllustrationColors";

interface Props {
  className?: string;
}

export function TutorialIllustration({ className }: Props) {
  const c = useIllustrationColors();

  return (
    <svg viewBox="0 0 400 200" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      <g transform="translate(40, 10)">
        <rect width="320" height="170" rx="14" fill={c.surface} stroke={c.border} strokeWidth="1.5" />
        {/* Dot grid */}
        {Array.from({ length: 8 }).map((_, i) =>
          Array.from({ length: 4 }).map((_, j) => (
            <circle key={`${i}-${j}`} cx={20 + i * 40} cy={20 + j * 40} r="1" fill={c.g2} opacity="0.4" />
          )),
        )}
        {/* Path glow */}
        <path d="M30,140 C50,140 60,90 100,80 C140,70 130,120 170,120 C210,120 200,60 240,50 C260,44 280,50 290,40" fill="none" stroke={c.accent} strokeWidth="3" opacity="0.12" strokeLinecap="round" />
        {/* Path dashed */}
        <path d="M30,140 C50,140 60,90 100,80 C140,70 130,120 170,120 C210,120 200,60 240,50 C260,44 280,50 290,40" fill="none" stroke={c.accent} strokeWidth="2" strokeDasharray="8 6" opacity="0.35" strokeLinecap="round" />

        {/* Step nodes */}
        {([
          [30, 140, "1", 160],
          [100, 80, "2", 100],
          [170, 120, "3", 142],
          [240, 50, "", 70],
        ] as const).map(([x, y, label, ly], i) => (
          <g key={i} transform={`translate(${x},${y})`}>
            <circle r="12" fill={i === 3 ? c.accent : c.accentLt} opacity={i === 3 ? 0.2 : 1} stroke={c.accent} strokeWidth="1.5" />
            {i < 3 ? (
              <text textAnchor="middle" y="4" fontSize="10" fill={c.accent} fontWeight="700" fontFamily="'Noto Sans JP', sans-serif">{label}</text>
            ) : (
              <g>
                <circle r="5" fill={c.accent} opacity="0.4" />
                <circle r="2" fill={c.accent} opacity="0.8" />
              </g>
            )}
            <text x="0" y={ly - y} textAnchor="middle" fontSize="7" fill={c.sub} fontFamily="'Noto Sans JP', sans-serif">
              {["基本操作", "入力", "生成", "活用"][i]}
            </text>
          </g>
        ))}

        {/* Plus icon */}
        <g transform="translate(290, 28)">
          <line x1="0" y1="-6" x2="0" y2="6" stroke={c.accent} strokeWidth="1.5" strokeLinecap="round" opacity="0.4" />
          <line x1="-6" y1="0" x2="6" y2="0" stroke={c.accent} strokeWidth="1.5" strokeLinecap="round" opacity="0.4" />
        </g>

        {/* Cursor */}
        <g transform="translate(140, 96)">
          <polygon points="0,0 0,14 4.5,11 7,18 10,17 7.5,10 12,8" fill={c.accent} opacity="0.55" />
        </g>
      </g>
      <text x="200" y="198" textAnchor="middle" fontSize="13" fill={c.sub} fontFamily="'Noto Sans JP', sans-serif" fontWeight="500">3分でわかる Scoria ガイドツアー</text>
    </svg>
  );
}
