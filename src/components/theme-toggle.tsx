import { Sun, Moon } from "@phosphor-icons/react";
import { useTheme } from "./theme-provider";
import { Button } from "./ui/button";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  const resolvedDark =
    theme === "dark" ||
    (theme === "system" &&
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(resolvedDark ? "light" : "dark")}
      aria-label={resolvedDark ? "ライトモードに切替" : "ダークモードに切替"}
    >
      {resolvedDark ? <Sun size={20} /> : <Moon size={20} />}
    </Button>
  );
}
