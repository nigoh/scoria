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

// 図版の色は index.css のトークンと同じコンソール配色に揃える（ADR-0026）。
// SVG 属性に CSS 変数を渡せない箇所があるため、ここが図版側の正本になる。
// トークンを変えたらこの2つも合わせて変える。
const light: IllustrationColors = {
  bg: "#f4f6f7",
  text: "#132029",
  sub: "#5a6b75",
  accent: "#a86a12",
  accentLt: "#f0e2c8",
  accentPale: "#f8f1e3",
  cardBg: "#ffffff",
  border: "#d3dade",
  surface: "#e7ebed",
  g1: "#e7ebed",
  g2: "#d3dade",
  g3: "#9aa8b0",
  g4: "#5a6b75",
};

const dark: IllustrationColors = {
  bg: "#0e1418",
  text: "#c4d1d8",
  sub: "#6b7f89",
  accent: "#e8a33d",
  accentLt: "#3d2f18",
  accentPale: "#2a2114",
  cardBg: "#131b21",
  border: "#24323c",
  surface: "#18222a",
  g1: "#18222a",
  g2: "#24323c",
  g3: "#3f5561",
  g4: "#6b7f89",
};

export function useIllustrationColors(): IllustrationColors {
  const { theme } = useTheme();
  return getResolved(theme) === "dark" ? dark : light;
}
