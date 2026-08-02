/**
 * ヒーローの背景（ADR-0026）。
 *
 * 以前は幾何図形が漂うアニメーションだったが、コンソール方向とは噛み合わないため
 * 静止した細かい格子に置き換えた。動かないので視差や reduced-motion の考慮も要らない。
 */
export function HeroBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      <div
        className="absolute inset-0 opacity-40 dark:opacity-60"
        style={{
          backgroundImage:
            "linear-gradient(to right, hsl(var(--border)) 1px, transparent 1px)," +
            "linear-gradient(to bottom, hsl(var(--border)) 1px, transparent 1px)",
          backgroundSize: "56px 56px",
          maskImage: "radial-gradient(ellipse 75% 60% at 30% 45%, #000 15%, transparent 75%)",
          WebkitMaskImage: "radial-gradient(ellipse 75% 60% at 30% 45%, #000 15%, transparent 75%)",
        }}
      />
    </div>
  );
}
