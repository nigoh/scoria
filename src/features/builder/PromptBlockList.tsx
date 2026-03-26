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
import { PromptBlock } from "./PromptBlock";
import { useExtensionStore } from "@/stores/extensionStore";

export function PromptBlockList() {
  const { generatedExtension, reorderBlocks, toggleBlock, updateBlockContent } =
    useExtensionStore();

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

  return (
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
              onContentChange={(content) => updateBlockContent(block.id, content)}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  );
}
