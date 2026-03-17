import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import { arrayMove } from "@dnd-kit/sortable";
import type { GeneratedPromptData } from "@/types";
import {
  recomputeFullText,
  recomputeSystemPrompt,
  recomputeUserPrompt,
} from "@/lib/prompt";

interface PromptState {
  generatedPrompt: GeneratedPromptData | null;
  isImproving: boolean;
  improvementResult: string | null;
  setGeneratedPrompt: (data: GeneratedPromptData) => void;
  reorderBlocks: (activeId: string, overId: string) => void;
  toggleBlock: (blockId: string) => void;
  updateBlockContent: (blockId: string, content: string) => void;
  setImproving: (v: boolean) => void;
  setImprovementResult: (result: string | null) => void;
  reset: () => void;
}

export const usePromptStore = create<PromptState>()(
  persist(
    (set) => ({
      generatedPrompt: null,
      isImproving: false,
      improvementResult: null,

      setGeneratedPrompt: (data) => set({ generatedPrompt: data }),

      reorderBlocks: (activeId, overId) =>
        set((state) => {
          if (!state.generatedPrompt) return state;
          const blocks = state.generatedPrompt.blocks;
          const oldIndex = blocks.findIndex((b) => b.id === activeId);
          const newIndex = blocks.findIndex((b) => b.id === overId);
          if (oldIndex === -1 || newIndex === -1) return state;
          const newBlocks = arrayMove(blocks, oldIndex, newIndex);
          return {
            generatedPrompt: {
              ...state.generatedPrompt,
              blocks: newBlocks,
              systemPrompt: recomputeSystemPrompt(newBlocks),
              userPrompt: recomputeUserPrompt(newBlocks),
              fullText: recomputeFullText(newBlocks),
            },
          };
        }),

      toggleBlock: (blockId) =>
        set((state) => {
          if (!state.generatedPrompt) return state;
          const newBlocks = state.generatedPrompt.blocks.map((b) =>
            b.id === blockId ? { ...b, enabled: !b.enabled } : b,
          );
          return {
            generatedPrompt: {
              ...state.generatedPrompt,
              blocks: newBlocks,
              systemPrompt: recomputeSystemPrompt(newBlocks),
              userPrompt: recomputeUserPrompt(newBlocks),
              fullText: recomputeFullText(newBlocks),
            },
          };
        }),

      updateBlockContent: (blockId, content) =>
        set((state) => {
          if (!state.generatedPrompt) return state;
          const newBlocks = state.generatedPrompt.blocks.map((b) =>
            b.id === blockId ? { ...b, content } : b,
          );
          return {
            generatedPrompt: {
              ...state.generatedPrompt,
              blocks: newBlocks,
              systemPrompt: recomputeSystemPrompt(newBlocks),
              userPrompt: recomputeUserPrompt(newBlocks),
              fullText: recomputeFullText(newBlocks),
            },
          };
        }),

      setImproving: (v) => set({ isImproving: v }),
      setImprovementResult: (result) => set({ improvementResult: result }),

      reset: () =>
        set({
          generatedPrompt: null,
          isImproving: false,
          improvementResult: null,
        }),
    }),
    {
      name: "scoria-prompt",
      storage: createJSONStorage(() => sessionStorage),
    },
  ),
);
