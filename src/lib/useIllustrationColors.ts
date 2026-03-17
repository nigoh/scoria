import { useTheme } from "@/components/theme-provider";

export interface IllustrationColors {
  bg: string;
  text: string;
  sub: string;
  accent: string;
  accentLt: string;
  accentPale: string;
  cardBg: string;
  border: string;
  surface: string;
  g1: string;
  g2: string;
  g3: string;
  g4: string;
}

function getResolved(theme: string): "light" | "dark" {
  if (theme === "system") {
    return typeof window !== "undefined" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }
  return theme as "light" | "dark";
}

const light: IllustrationColors = {
  bg: "#ffffff",
  text: "#111827",
  sub: "#6b7280",
  accent: "#3b82f6",
  accentLt: "#dbeafe",
  accentPale: "#eff6ff",
  cardBg: "#f9fafb",
  border: "#e5e7eb",
  surface: "#f3f4f6",
  g1: "#e5e7eb",
  g2: "#d1d5db",
  g3: "#9ca3af",
  g4: "#6b7280",
};

const dark: IllustrationColors = {
  bg: "#09090b",
  text: "#fafafa",
  sub: "#a1a1aa",
  accent: "#60a5fa",
  accentLt: "#172554",
  accentPale: "#1e3a5f",
  cardBg: "#18181b",
  border: "#3f3f46",
  surface: "#18181b",
  g1: "#27272a",
  g2: "#3f3f46",
  g3: "#52525b",
  g4: "#71717a",
};

export function useIllustrationColors(): IllustrationColors {
  const { theme } = useTheme();
  return getResolved(theme) === "dark" ? dark : light;
}
