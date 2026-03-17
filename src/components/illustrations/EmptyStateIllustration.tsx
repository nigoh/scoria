import { useIllustrationColors } from "@/lib/useIllustrationColors";

interface Props {
  className?: string;
}

export function EmptyStateIllustration({ className }: Props) {
  const c = useIllustrationColors();

  return (
    <svg viewBox="0 0 320 280" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      <g transform="translate(90, 30)">
        <path d="M0,100 L20,20 L120,20 L140,100 Z" fill={c.surface} stroke={c.border} strokeWidth="1.5" />
        <path d="M0,100 L140,100 L140,130 C140,136 136,140 130,140 L10,140 C4,140 0,136 0,130 Z" fill={c.surface} stroke={c.border} strokeWidth="1.5" />
        <line x1="0" y1="100" x2="140" y2="100" stroke={c.border} strokeWidth="1.5" />
        <rect x="30" y="36" width="44" height="56" rx="4" fill="none" stroke={c.g2} strokeWidth="1.5" strokeDasharray="5 4" opacity="0.5" />
        <rect x="38" y="48" width="20" height="2.5" rx="1.25" fill={c.g2} opacity="0.3" />
        <rect x="38" y="56" width="28" height="2.5" rx="1.25" fill={c.g2} opacity="0.2" />
        <rect x="38" y="64" width="16" height="2.5" rx="1.25" fill={c.g2} opacity="0.15" />
        <rect x="66" y="42" width="44" height="52" rx="4" fill="none" stroke={c.g2} strokeWidth="1" strokeDasharray="5 4" opacity="0.25" />
        <circle cx="70" cy="114" r="14" fill={c.accentLt} />
        <text x="70" y="120" textAnchor="middle" fontSize="16" fill={c.accent} opacity="0.5" fontWeight="700">?</text>
      </g>
      <circle cx="60" cy="80" r="5" fill={c.accent} opacity="0.06" />
      <circle cx="270" cy="50" r="7" fill={c.accent} opacity="0.04" />
      <circle cx="50" cy="200" r="4" fill={c.accent} opacity="0.07" />
      <circle cx="280" cy="180" r="6" fill={c.accent} opacity="0.05" />
      <text x="160" y="210" textAnchor="middle" fontSize="14" fill={c.sub} fontFamily="'Noto Sans JP', sans-serif" fontWeight="600">まだプロンプトがありません</text>
      <text x="160" y="232" textAnchor="middle" fontSize="11" fill={c.sub} fontFamily="'Noto Sans JP', sans-serif" opacity="0.6">ウィザードを完了してプロンプトを生成しましょう</text>
    </svg>
  );
}
