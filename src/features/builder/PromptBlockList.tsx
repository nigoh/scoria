import { useState } from "react";
import {
  DndContext,
  closestCenter,
  PointerSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  verticalListSortingStrategy,
  sortableKeyboardCoordinates,
} from "@dnd-kit/sortable";
import { Plus } from "@phosphor-icons/react";
import { PromptBlock } from "./PromptBlock";
import { useExtensionStore } from "@/stores/extensionStore";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export function PromptBlockList() {
  const {
    generatedExtension,
    reorderBlocks,
    toggleBlock,
    updateBlockContent,
    addBlock,
    removeBlock,
  } = useExtensionStore();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [newLabel, setNewLabel] = useState("");
  const [newContent, setNewContent] = useState("");

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  if (!generatedExtension) return null;

  const blocks = generatedExtension.blocks;

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      reorderBlocks(String(active.id), String(over.id));
    }
  };

  const handleAddBlock = () => {
    if (!newLabel.trim()) return;
    addBlock(newLabel.trim(), newContent);
    setNewLabel("");
    setNewContent("");
    setDialogOpen(false);
  };

  return (
    <>
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={handleDragEnd}
      >
        <SortableContext
          items={blocks.map((b) => b.id)}
          strategy={verticalListSortingStrategy}
        >
          <div className="space-y-2">
            {blocks.map((block) => (
              <PromptBlock
                key={block.id}
                block={block}
                onToggle={() => toggleBlock(block.id)}
                onContentChange={(content) =>
                  updateBlockContent(block.id, content)
                }
                onDelete={() => removeBlock(block.id)}
              />
            ))}
          </div>
        </SortableContext>
      </DndContext>

      <Button
        variant="outline"
        size="sm"
        className="mt-3 w-full gap-1.5"
        onClick={() => setDialogOpen(true)}
      >
        <Plus size={14} />
        ブロックを追加
      </Button>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ブロックを追加</DialogTitle>
            <DialogDescription>
              カスタムのコンテンツブロックを追加します。
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="block-label">ラベル</Label>
              <Input
                id="block-label"
                placeholder="例: 追加の指示"
                value={newLabel}
                onChange={(e) => setNewLabel(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="block-content">内容</Label>
              <Textarea
                id="block-content"
                placeholder="ブロックの内容を入力..."
                rows={6}
                value={newContent}
                onChange={(e) => setNewContent(e.target.value)}
                className="font-mono text-xs"
              />
            </div>
            <div className="flex justify-end gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setDialogOpen(false)}
              >
                キャンセル
              </Button>
              <Button
                size="sm"
                onClick={handleAddBlock}
                disabled={!newLabel.trim()}
              >
                追加
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
