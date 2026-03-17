import { useIllustrationColors } from "@/lib/useIllustrationColors";

interface Props {
  className?: string;
}

export function StepsIllustration({ className }: Props) {
  const c = useIllustrationColors();

  return (
    <svg viewBox="0 0 520 130" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      {/* Step 1: Compass */}
      <g transform="translate(8, 8)">
        <rect width="100" height="100" rx="12" fill={c.accentPale} />
        <circle cx="50" cy="42" r="24" fill={c.bg} stroke={c.accent} strokeWidth="2" />
        <circle cx="50" cy="42" r="4" fill={c.accent} />
        <polygon points="50,20 46,42 50,48 54,42" fill={c.accent} opacity="0.65" />
        <polygon points="50,64 46,42 50,36 54,42" fill={c.g2} opacity="0.35" />
        <rect x="16" y="78" width="68" height="4" rx="2" fill={c.g1} />
        <rect x="16" y="78" width="20" height="4" rx="2" fill={c.accent} opacity="0.6" />
      </g>
      {/* Arrow 1→2 */}
      <g transform="translate(112, 48)">
        <line x1="0" y1="10" x2="20" y2="10" stroke={c.accent} strokeWidth="2" strokeDasharray="4 3" opacity="0.3" />
        <polygon points="20,6 28,10 20,14" fill={c.accent} opacity="0.3" />
      </g>

      {/* Step 2: Form */}
      <g transform="translate(138, 8)">
        <rect width="100" height="100" rx="12" fill={c.accentPale} />
        <rect x="14" y="16" width="72" height="60" rx="6" fill={c.bg} stroke={c.g2} strokeWidth="1.2" />
        <rect x="20" y="24" width="24" height="3" rx="1.5" fill={c.accent} opacity="0.5" />
        <rect x="20" y="32" width="56" height="3" rx="1.5" fill={c.g2} opacity="0.5" />
        <rect x="20" y="42" width="56" height="10" rx="3" fill={c.bg} stroke={c.accent} strokeWidth="1" />
        <rect x="24" y="46" width="30" height="2.5" rx="1.25" fill={c.accent} opacity="0.3" />
        <rect x="20" y="58" width="56" height="10" rx="3" fill={c.bg} stroke={c.g2} strokeWidth="1" />
        <rect x="14" y="82" width="28" height="10" rx="5" fill={c.accent} opacity="0.15" />
        <rect x="20" y="86" width="16" height="2.5" rx="1.25" fill={c.accent} opacity="0.5" />
      </g>
      {/* Arrow 2→3 */}
      <g transform="translate(242, 48)">
        <line x1="0" y1="10" x2="20" y2="10" stroke={c.accent} strokeWidth="2" strokeDasharray="4 3" opacity="0.3" />
        <polygon points="20,6 28,10 20,14" fill={c.accent} opacity="0.3" />
      </g>

      {/* Step 3: Transform */}
      <g transform="translate(268, 8)">
        <rect width="100" height="100" rx="12" fill={c.accentPale} />
        <rect x="10" y="18" width="30" height="12" rx="3" fill={c.g2} opacity="0.5" />
        <rect x="10" y="34" width="30" height="8" rx="3" fill={c.g2} opacity="0.4" />
        <rect x="10" y="46" width="30" height="16" rx="3" fill={c.g2} opacity="0.3" />
        <rect x="46" y="18" width="3.5" height="46" rx="1.75" fill={c.accent} opacity="0.35" />
        <rect x="56" y="16" width="34" height="52" rx="5" fill={c.bg} stroke={c.accent} strokeWidth="1.5" />
        <rect x="60" y="22" width="26" height="3" rx="1.5" fill={c.accent} opacity="0.5" />
        <rect x="60" y="30" width="20" height="3" rx="1.5" fill={c.accent} opacity="0.35" />
        <rect x="60" y="38" width="26" height="3" rx="1.5" fill={c.accent} opacity="0.25" />
        <rect x="60" y="46" width="14" height="3" rx="1.5" fill={c.accent} opacity="0.18" />
        <rect x="60" y="54" width="22" height="3" rx="1.5" fill={c.accent} opacity="0.12" />
        <g transform="translate(86, 12)">
          <line x1="0" y1="-5" x2="0" y2="5" stroke={c.accent} strokeWidth="1.5" strokeLinecap="round" />
          <line x1="-5" y1="0" x2="5" y2="0" stroke={c.accent} strokeWidth="1.5" strokeLinecap="round" />
        </g>
        <rect x="14" y="74" width="72" height="16" rx="4" fill={c.accent} opacity="0.1" />
        <rect x="22" y="80" width="8" height="3" rx="1.5" fill={c.accent} opacity="0.6" />
        <rect x="34" y="80" width="40" height="3" rx="1.5" fill={c.accent} opacity="0.3" />
      </g>
      {/* Arrow 3→4 */}
      <g transform="translate(372, 48)">
        <line x1="0" y1="10" x2="20" y2="10" stroke={c.accent} strokeWidth="2" strokeDasharray="4 3" opacity="0.3" />
        <polygon points="20,6 28,10 20,14" fill={c.accent} opacity="0.3" />
      </g>

      {/* Step 4: Export */}
      <g transform="translate(398, 8)">
        <rect width="100" height="100" rx="12" fill={c.accentPale} />
        <rect x="12" y="14" width="40" height="50" rx="4" fill={c.bg} stroke={c.accent} strokeWidth="1.5" />
        <rect x="18" y="22" width="20" height="2.5" rx="1.25" fill={c.accent} opacity="0.5" />
        <rect x="18" y="29" width="28" height="2" rx="1" fill={c.g2} opacity="0.4" />
        <rect x="18" y="36" width="24" height="2" rx="1" fill={c.g2} opacity="0.3" />
        <rect x="18" y="43" width="28" height="2" rx="1" fill={c.g2} opacity="0.2" />
        <g transform="translate(56, 28)">
          <line x1="0" y1="0" x2="14" y2="-8" stroke={c.accent} strokeWidth="1.5" opacity="0.4" />
          <line x1="0" y1="0" x2="16" y2="0" stroke={c.accent} strokeWidth="1.5" opacity="0.4" />
          <line x1="0" y1="0" x2="14" y2="8" stroke={c.accent} strokeWidth="1.5" opacity="0.4" />
        </g>
        <circle cx="78" cy="20" r="8" fill={c.accentLt} stroke={c.accent} strokeWidth="1" />
        <text x="78" y="23" textAnchor="middle" fontSize="7" fill={c.accent} fontWeight="700" fontFamily="'Noto Sans JP', sans-serif">AI</text>
        <rect x="68" y="32" width="22" height="12" rx="3" fill={c.bg} stroke={c.g2} strokeWidth="1" />
        <text x="79" y="41" textAnchor="middle" fontSize="6" fill={c.g3} fontFamily="monospace">.md</text>
        <rect x="68" y="48" width="22" height="12" rx="3" fill={c.bg} stroke={c.g2} strokeWidth="1" />
        <text x="79" y="57" textAnchor="middle" fontSize="6" fill={c.g3} fontFamily="monospace">.pdf</text>
      </g>

      {/* Step numbers */}
      {[1, 2, 3, 4].map((n, i) => (
        <g key={n} transform={`translate(${58 + i * 130}, 120)`}>
          <circle r="10" fill={c.accent} opacity="0.12" />
          <text textAnchor="middle" y="4" fontSize="11" fontWeight="700" fill={c.accent} fontFamily="'Noto Sans JP', sans-serif">{n}</text>
        </g>
      ))}
    </svg>
  );
}
