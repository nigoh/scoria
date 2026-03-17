import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { DotsSixVertical } from "@phosphor-icons/react";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { PromptBlock as PromptBlockType } from "@/types";

interface PromptBlockProps {
  block: PromptBlockType;
  onToggle: () => void;
}

export function PromptBlock({ block, onToggle }: PromptBlockProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: block.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "rounded-lg border border-border bg-card p-3 transition-shadow",
        isDragging && "z-50 shadow-lg",
        !block.enabled && "opacity-50",
      )}
    >
      <div className="flex items-start gap-2">
        <button
          type="button"
          className="mt-0.5 cursor-grab touch-none text-muted-foreground hover:text-foreground active:cursor-grabbing"
          {...attributes}
          {...listeners}
        >
          <DotsSixVertical size={16} />
        </button>
        <div className="flex-1 space-y-1">
          <div className="flex items-center justify-between">
            <Badge variant="outline" className="text-[10px]">
              {block.labelJa}
            </Badge>
            <Switch checked={block.enabled} onCheckedChange={onToggle} />
          </div>
          <pre
            className={cn(
              "whitespace-pre-wrap font-mono text-xs leading-relaxed text-foreground",
              !block.enabled && "line-through",
            )}
          >
            {block.content}
          </pre>
        </div>
      </div>
    </div>
  );
}
