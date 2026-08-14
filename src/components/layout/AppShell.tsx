import { NavLink, Outlet } from "react-router-dom";
import { Compass, Graph } from "@phosphor-icons/react";
import { ThemeToggle } from "@/components/theme-toggle";
import { Logo } from "./Logo";
import { cn } from "@/lib/utils";

const navItems = [
  { to: "/builder", label: "ビルダー", icon: Compass },
  { to: "/graph", label: "論文グラフ", icon: Graph },
];

export function AppShell() {
  return (
    <div className="min-h-screen bg-background">
      {/* コンソールのタイトルバー（ADR-0026）。角丸なし・罫線で区切る */}
      <header className="sticky top-0 z-40 border-b border-border bg-card">
        <div className="mx-auto flex h-12 max-w-6xl items-center justify-between pr-3">
          <div className="flex h-full items-stretch">
            <NavLink
              to="/"
              className="animate-logo-in flex items-center border-r border-border px-4 transition-opacity hover:opacity-80"
            >
              <Logo />
            </NavLink>
            <nav className="flex items-stretch">
              {navItems.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) =>
                    cn(
                      // 琥珀は主アクション専用（ADR-0026）。現在地は下線で示し、面を塗らない
                      "flex items-center gap-1.5 border-r border-border px-4 text-sm transition-colors",
                      isActive
                        ? "text-foreground shadow-[inset_0_-2px_0_hsl(var(--primary))]"
                        : "text-muted-foreground hover:bg-accent hover:text-foreground",
                    )
                  }
                >
                  <item.icon size={15} />
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
