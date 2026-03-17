import { useIllustrationColors } from "@/lib/useIllustrationColors";

interface Props {
  className?: string;
}

export function MedicalIllustration({ className }: Props) {
  const c = useIllustrationColors();
  const fg = c.bg === "#ffffff" ? "#fff" : "#000";
  return (
    <svg viewBox="0 0 100 86" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      <circle cx="50" cy="32" r="18" fill={c.accentLt} />
      <path d="M42,32 L58,32 M50,24 L50,40" stroke={c.accent} strokeWidth="2.5" strokeLinecap="round" />
      {["P", "I", "C", "O"].map((l, i) => (
        <g key={l}>
          <rect x={12 + i * 22} y={60} width={18} height={16} rx={3} fill={c.accent} opacity={0.55 - i * 0.1} />
          <text x={21 + i * 22} y={71} textAnchor="middle" fontSize="8" fill={fg} fontFamily="monospace" fontWeight="700">{l}</text>
        </g>
      ))}
    </svg>
  );
}

export function CSIllustration({ className }: Props) {
  const c = useIllustrationColors();
  const termBg = c.bg === "#ffffff" ? "#1f2937" : "#18181b";
  const termScreen = c.bg === "#ffffff" ? "#111827" : "#09090b";
  return (
    <svg viewBox="0 0 100 86" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      <rect x="14" y="10" width="72" height="44" rx="5" fill={termBg} />
      <rect x="18" y="16" width="64" height="34" rx="3" fill={termScreen} />
      <text x="24" y="30" fontSize="10" fill={c.accent} fontFamily="monospace" fontWeight="700">&gt;_</text>
      <rect x="44" y="25" width="30" height="2.5" rx="1.25" fill={c.accent} opacity="0.4" />
      <rect x="24" y="34" width="48" height="2" rx="1" fill={c.g3} opacity="0.25" />
      <text x="30" y="72" fontSize="13" fill={c.accent} opacity="0.3" fontFamily="monospace" fontWeight="700">{"{ }"}</text>
    </svg>
  );
}

export function SocialScienceIllustration({ className }: Props) {
  const c = useIllustrationColors();
  return (
    <svg viewBox="0 0 100 86" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      {[[34, 28], [66, 28], [50, 50]].map(([cx, cy], i) => (
        <g key={i}>
          <circle cx={cx} cy={cy} r="12" fill={c.accentLt} />
          <circle cx={cx} cy={cy} r="4" fill={c.accent} opacity={0.5 - i * 0.1} />
        </g>
      ))}
      <line x1="42" y1="32" x2="46" y2="42" stroke={c.accent} strokeWidth="1.2" opacity="0.2" />
      <line x1="58" y1="32" x2="54" y2="42" stroke={c.accent} strokeWidth="1.2" opacity="0.2" />
      <line x1="44" y1="26" x2="58" y2="26" stroke={c.accent} strokeWidth="1.2" opacity="0.2" />
      <rect x="14" y="68" width="72" height="5" rx="2.5" fill={c.g1} />
      <rect x="14" y="68" width="44" height="5" rx="2.5" fill={c.accent} opacity="0.2" />
    </svg>
  );
}

export function InterdisciplinaryIllustration({ className }: Props) {
  const c = useIllustrationColors();
  return (
    <svg viewBox="0 0 100 86" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} aria-hidden="true">
      <circle cx="40" cy="36" r="20" fill={c.accent} opacity="0.1" />
      <circle cx="58" cy="32" r="20" fill={c.accent} opacity="0.08" />
      <circle cx="50" cy="50" r="20" fill={c.accent} opacity="0.06" />
      <circle cx="50" cy="39" r="5" fill={c.accent} opacity="0.35" />
      {[0, 1, 2, 3, 4].map((i) => (
        <rect key={i} x={10 + i * 17} y={68} width={13} height={8} rx={2} fill={c.accent} opacity={0.35 - i * 0.06} />
      ))}
    </svg>
  );
}
