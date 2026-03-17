export function HeroBackground() {
  return (
    <div
      className="pointer-events-none absolute inset-0 overflow-hidden"
      aria-hidden="true"
    >
      {/* 六角形 */}
      <svg
        className="absolute -top-10 left-[10%] h-32 w-32 animate-geo-float-1 text-primary opacity-[0.07]"
        viewBox="0 0 100 100"
      >
        <polygon
          points="50,3 93,25 93,75 50,97 7,75 7,25"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        />
      </svg>

      {/* 円 */}
      <svg
        className="absolute top-20 right-[15%] h-24 w-24 animate-geo-float-2 text-primary opacity-[0.06]"
        viewBox="0 0 100 100"
      >
        <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeWidth="2" />
      </svg>

      {/* 菱形 */}
      <svg
        className="absolute top-[40%] left-[5%] h-20 w-20 animate-geo-float-3 text-primary opacity-[0.08]"
        viewBox="0 0 100 100"
      >
        <polygon
          points="50,5 95,50 50,95 5,50"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        />
      </svg>

      {/* 三角形 */}
      <svg
        className="absolute bottom-10 right-[8%] h-28 w-28 animate-geo-float-4 text-primary opacity-[0.06]"
        viewBox="0 0 100 100"
      >
        <polygon
          points="50,8 95,92 5,92"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        />
      </svg>

      {/* 小さな円 */}
      <svg
        className="absolute top-[60%] right-[35%] h-14 w-14 animate-geo-float-5 text-primary opacity-[0.10]"
        viewBox="0 0 100 100"
      >
        <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeWidth="3" />
      </svg>

      {/* ドット格子 */}
      <svg
        className="absolute -bottom-6 left-[25%] h-36 w-36 animate-geo-float-2 text-primary opacity-[0.05]"
        viewBox="0 0 100 100"
      >
        {[0, 25, 50, 75, 100].map((x) =>
          [0, 25, 50, 75, 100].map((y) => (
            <circle key={`${x}-${y}`} cx={x} cy={y} r="2" fill="currentColor" />
          )),
        )}
      </svg>

      {/* 六角形（小） */}
      <svg
        className="absolute top-[15%] right-[45%] h-16 w-16 animate-geo-float-3 text-primary opacity-[0.08]"
        viewBox="0 0 100 100"
      >
        <polygon
          points="50,3 93,25 93,75 50,97 7,75 7,25"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
        />
      </svg>
    </div>
  );
}
