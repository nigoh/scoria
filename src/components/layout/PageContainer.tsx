import { cn } from "@/lib/utils";

interface PageContainerProps {
  children: React.ReactNode;
  className?: string;
  wide?: boolean;
}

export function PageContainer({
  children,
  className,
  wide,
}: PageContainerProps) {
  return (
    <div
      className={cn(
        "mx-auto px-6 py-8",
        wide ? "max-w-full" : "max-w-6xl",
        className,
      )}
    >
      {children}
    </div>
  );
}
