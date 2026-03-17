import { ArrowSquareOut } from "@phosphor-icons/react";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import type { AcademicDatabase } from "@/types";

interface DatabaseItemProps {
  database: AcademicDatabase;
  enabled: boolean;
  onToggle: () => void;
}

const accessLabel: Record<string, string> = {
  free: "無料",
  paid: "有料",
  oa: "OA",
};

export function DatabaseItem({ database, enabled, onToggle }: DatabaseItemProps) {
  return (
    <div className="flex items-center justify-between gap-3 py-2">
      <div className="flex min-w-0 flex-1 items-center gap-2">
        <span className="truncate text-sm font-medium text-foreground">
          {database.name}
        </span>
        <Badge variant="outline" className="shrink-0 text-[10px]">
          {accessLabel[database.access] ?? database.access}
        </Badge>
        <a
          href={database.url}
          target="_blank"
          rel="noopener noreferrer"
          className="shrink-0 text-muted-foreground hover:text-foreground"
          aria-label={`${database.name}を開く`}
        >
          <ArrowSquareOut size={14} />
        </a>
      </div>
      <Switch checked={enabled} onCheckedChange={onToggle} />
    </div>
  );
}
