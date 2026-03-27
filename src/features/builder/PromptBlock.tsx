import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { DotsSixVertical, Trash } from "@phosphor-icons/react";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import type { ContentBlock } from "@/types";

interface PromptBlockProps {
  block: ContentBlock;
  onToggle: () => void;
  onContentChange: (content: string) => void;
  onDelete?: () => void;
}

export function PromptBlock({ block, onToggle, onContentChange, onDelete }: PromptBlockProps) {
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
        <div className="flex-1 space-y-2">
          <div className="flex items-center justify-between">
            <Badge variant="outline" className="text-[10px]">
              {block.label}
            </Badge>
            <div className="flex items-center gap-1.5">
              {onDelete && (
                <button
                  type="button"
                  onClick={onDelete}
                  className="text-muted-foreground hover:text-destructive"
                  title="ブロックを削除"
                >
                  <Trash size={14} />
                </button>
              )}
              <Switch checked={block.enabled} onCheckedChange={onToggle} />
            </div>
          </div>
          <Textarea
            value={block.content}
            onChange={(e) => onContentChange(e.target.value)}
            rows={6}
            className={cn(
              "font-mono text-xs leading-relaxed",
              !block.enabled && "line-through opacity-60",
            )}
          />
        </div>
      </div>
    </div>
  );
}
