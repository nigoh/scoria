interface StepHeadingProps {
  title: string;
  hint?: string;
}

/**
 * ステップ共通の見出し（ADR-0026）。
 * 見出しの前に置く `▍` がコンソールの区切り記号として働き、階層を罫線なしで示す。
 */
export function StepHeading({ title, hint }: StepHeadingProps) {
  return (
    <div>
      <h2 className="flex items-baseline gap-1.5 text-base font-bold">
        <span className="text-primary" aria-hidden="true">
          ▍
        </span>
        {title}
      </h2>
      {hint && (
        <p className="mt-1 pl-4 font-sans text-xs leading-relaxed text-muted-foreground">{hint}</p>
      )}
    </div>
  );
}
