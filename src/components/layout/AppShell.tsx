import { NavLink, Outlet } from "react-router-dom";
import { Compass } from "@phosphor-icons/react";
import { ThemeToggle } from "@/components/theme-toggle";
import { useTheme } from "@/components/theme-provider";
import { cn } from "@/lib/utils";

const navItems = [
  { to: "/builder", label: "ビルダー", icon: Compass },
];

function getResolvedTheme(theme: string): "light" | "dark" {
  if (theme === "system") {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }
  return theme as "light" | "dark";
}

export function AppShell() {
  const { theme } = useTheme();
  const resolved = getResolvedTheme(theme);
  const logoSrc =
    resolved === "dark"
      ? "/scoria-logo-dark.svg"
      : "/scoria-logo-light.svg";

  return (
    <div className="min-h-screen bg-background">
      <header className="sticky top-0 z-40 border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-6">
          <div className="flex items-center gap-6">
            <NavLink
              to="/"
              className="animate-logo-in transition-transform duration-200 hover:scale-[1.03]"
            >
              <img
                src={logoSrc}
                alt="Scoria"
                className="h-7"
              />
            </NavLink>
            <nav className="flex items-center gap-1">
              {navItems.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) =>
                    cn(
                      "flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors",
                      isActive
                        ? "bg-primary/10 text-primary"
                        : "text-muted-foreground hover:text-foreground hover:bg-muted",
                    )
                  }
                >
                  <item.icon size={16} />
                  {item.label}
                </NavLink>
              ))}
            </nav>
          </div>
          <ThemeToggle />
        </div>
      </header>
      <Outlet />
    </div>
  );
}
