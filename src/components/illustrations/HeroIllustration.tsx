import { useIllustrationColors } from "@/lib/useIllustrationColors";

interface Props {
  className?: string;
}

export function HeroIllustration({ className }: Props) {
  const c = useIllustrationColors();

  return (
    <svg viewBox="0 0 560 300" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      {/* Left: Research query card */}
      <g transform="translate(20, 40)">
        <rect width="150" height="200" rx="12" fill={c.surface} stroke={c.border} strokeWidth="1.5" />
        <rect x="14" y="16" width="122" height="28" rx="6" fill={c.bg} stroke={c.g2} strokeWidth="1.2" />
        <circle cx="30" cy="30" r="6" fill="none" stroke={c.accent} strokeWidth="1.8" />
        <line x1="34" y1="34" x2="38" y2="38" stroke={c.accent} strokeWidth="1.8" strokeLinecap="round" />
        <rect x="44" y="26" width="60" height="3" rx="1.5" fill={c.g2} opacity="0.6" />
        <rect x="14" y="56" width="44" height="18" rx="9" fill={c.accentLt} stroke={c.accent} strokeWidth="1" opacity="0.8" />
        <rect x="20" y="62" width="32" height="3" rx="1.5" fill={c.accent} opacity="0.6" />
        <rect x="64" y="56" width="38" height="18" rx="9" fill={c.accentLt} stroke={c.accent} strokeWidth="1" opacity="0.6" />
        <rect x="70" y="62" width="26" height="3" rx="1.5" fill={c.accent} opacity="0.4" />
        <rect x="108" y="56" width="28" height="18" rx="9" fill={c.accentLt} stroke={c.accent} strokeWidth="1" opacity="0.4" />
        <rect x="114" y="62" width="16" height="3" rx="1.5" fill={c.accent} opacity="0.3" />
        <rect x="14" y="88" width="100" height="3" rx="1.5" fill={c.g2} opacity="0.5" />
        <rect x="14" y="98" width="80" height="3" rx="1.5" fill={c.g2} opacity="0.4" />
        <rect x="14" y="108" width="110" height="3" rx="1.5" fill={c.g2} opacity="0.3" />
        <rect x="14" y="118" width="60" height="3" rx="1.5" fill={c.g2} opacity="0.2" />
        <rect x="14" y="140" width="122" height="4" rx="2" fill={c.g1} />
        <rect x="14" y="140" width="40" height="4" rx="2" fill={c.accent} opacity="0.6" />
        <circle cx="54" cy="142" r="5" fill={c.accent} opacity="0.8" />
        <rect x="14" y="162" width="56" height="18" rx="4" fill={c.accent} opacity="0.12" />
        <rect x="22" y="168" width="40" height="3" rx="1.5" fill={c.accent} opacity="0.5" />
      </g>

      {/* Center: Animated flow */}
      <g transform="translate(195, 80)">
        <rect y="40" width="4" height="60" rx="2" fill={c.accent} opacity="0.3" />
        <circle r="5" fill={c.accent} opacity="0.15">
          <animateMotion dur="2.5s" repeatCount="indefinite" path="M10,100 C30,80 50,60 70,50 C90,40 110,45 130,40" />
          <animate attributeName="opacity" values="0.1;0.5;0.1" dur="2.5s" repeatCount="indefinite" />
        </circle>
        <circle r="3.5" fill={c.accent} opacity="0.1">
          <animateMotion dur="2.5s" begin="0.8s" repeatCount="indefinite" path="M10,100 C30,80 50,60 70,50 C90,40 110,45 130,40" />
          <animate attributeName="opacity" values="0.05;0.4;0.05" dur="2.5s" begin="0.8s" repeatCount="indefinite" />
        </circle>
        <circle r="2.5" fill={c.accent} opacity="0.08">
          <animateMotion dur="2.5s" begin="1.6s" repeatCount="indefinite" path="M10,100 C30,80 50,60 70,50 C90,40 110,45 130,40" />
          <animate attributeName="opacity" values="0.05;0.35;0.05" dur="2.5s" begin="1.6s" repeatCount="indefinite" />
        </circle>
        {/* Prompt structure block */}
        <g transform="translate(40, 30)">
          <rect width="56" height="80" rx="8" fill={c.accentPale} stroke={c.accent} strokeWidth="1.5" />
          <rect x="8" y="10" width="40" height="10" rx="3" fill={c.accent} opacity="0.55" />
          <rect x="8" y="24" width="40" height="10" rx="3" fill={c.accent} opacity="0.4" />
          <rect x="8" y="38" width="40" height="10" rx="3" fill={c.accent} opacity="0.28" />
          <rect x="8" y="52" width="40" height="10" rx="3" fill={c.accent} opacity="0.16" />
          <g transform="translate(48, 4)">
            <line x1="0" y1="-6" x2="0" y2="6" stroke={c.accent} strokeWidth="1.5" strokeLinecap="round" />
            <line x1="-6" y1="0" x2="6" y2="0" stroke={c.accent} strokeWidth="1.5" strokeLinecap="round" />
          </g>
        </g>
        <rect x="130" y="40" width="4" height="60" rx="2" fill={c.accent} opacity="0.3" />
      </g>

      {/* Right: AI response card */}
      <g transform="translate(370, 40)">
        <rect width="150" height="200" rx="12" fill={c.accentPale} stroke={c.accent} strokeWidth="1.5" opacity="0.9" />
        <rect x="14" y="14" width="36" height="20" rx="6" fill={c.accent} opacity="0.2" />
        <text x="32" y="28" textAnchor="middle" fontSize="10" fill={c.accent} fontWeight="700" fontFamily="'Noto Sans JP', sans-serif">AI</text>
        <rect x="58" y="14" width="78" height="20" rx="6" fill={c.bg} stroke={c.accent} strokeWidth="1" opacity="0.5" />
        <rect x="66" y="22" width="40" height="2.5" rx="1.25" fill={c.accent} opacity="0.4" />
        <rect x="14" y="48" width="90" height="4" rx="2" fill={c.accent} opacity="0.45" />
        <rect x="14" y="60" width="122" height="3" rx="1.5" fill={c.accent} opacity="0.3" />
        <rect x="14" y="70" width="100" height="3" rx="1.5" fill={c.accent} opacity="0.25" />
        <rect x="14" y="80" width="112" height="3" rx="1.5" fill={c.accent} opacity="0.2" />
        <rect x="14" y="90" width="78" height="3" rx="1.5" fill={c.accent} opacity="0.15" />
        <rect x="14" y="100" width="90" height="3" rx="1.5" fill={c.accent} opacity="0.12" />
        <rect x="14" y="130" width="60" height="24" rx="6" fill={c.accent} opacity="0.15" />
        <rect x="24" y="140" width="36" height="3" rx="1.5" fill={c.accent} opacity="0.5" />
        <rect x="82" y="130" width="54" height="24" rx="6" fill={c.bg} stroke={c.accent} strokeWidth="1" opacity="0.4" />
        <rect x="14" y="168" width="24" height="18" rx="4" fill={c.bg} stroke={c.g2} strokeWidth="1" />
        <text x="26" y="180" textAnchor="middle" fontSize="7" fill={c.g3} fontFamily="monospace">.md</text>
        <rect x="44" y="168" width="24" height="18" rx="4" fill={c.bg} stroke={c.g2} strokeWidth="1" />
        <text x="56" y="180" textAnchor="middle" fontSize="7" fill={c.g3} fontFamily="monospace">.pdf</text>
      </g>

      {/* Decorative dots */}
      <circle cx="185" cy="260" r="6" fill={c.accent} opacity="0.06" />
      <circle cx="360" cy="20" r="8" fill={c.accent} opacity="0.05" />
      <circle cx="540" cy="270" r="5" fill={c.accent} opacity="0.07" />
    </svg>
  );
}
