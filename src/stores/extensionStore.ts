import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { arrayMove } from "@dnd-kit/sortable";
import { nanoid } from "nanoid";
import type { GeneratedExtension, GeneratedFile } from "@/types";

interface ExtensionState {
  generatedExtension: GeneratedExtension | null;
  selectedFilePath: string | null;
  setGeneratedExtension: (data: GeneratedExtension) => void;
  updateFiles: (files: GeneratedFile[]) => void;
  setSelectedFilePath: (path: string | null) => void;
  reorderBlocks: (activeId: string, overId: string) => void;
  toggleBlock: (blockId: string) => void;
  updateBlockContent: (blockId: string, content: string) => void;
  addBlock: (label: string, content: string) => void;
  removeBlock: (blockId: string) => void;
  reset: () => void;
}

export const useExtensionStore = create<ExtensionState>()(
  persist(
    (set) => ({
      generatedExtension: null,
      selectedFilePath: null,

      setGeneratedExtension: (data) =>
        set({
          generatedExtension: data,
          selectedFilePath: data.files.length > 0 ? data.files[0].path : null,
        }),

      updateFiles: (files) =>
        set((state) => {
          if (!state.generatedExtension) return state;
          return {
            generatedExtension: { ...state.generatedExtension, files },
          };
        }),

      setSelectedFilePath: (path) => set({ selectedFilePath: path }),

      reorderBlocks: (activeId, overId) =>
        set((state) => {
          if (!state.generatedExtension) return state;
          const blocks = state.generatedExtension.blocks;
          const oldIndex = blocks.findIndex((b) => b.id === activeId);
          const newIndex = blocks.findIndex((b) => b.id === overId);
          if (oldIndex === -1 || newIndex === -1) return state;
          return {
            generatedExtension: {
              ...state.generatedExtension,
              blocks: arrayMove(blocks, oldIndex, newIndex),
            },
          };
        }),

      toggleBlock: (blockId) =>
        set((state) => {
          if (!state.generatedExtension) return state;
          return {
            generatedExtension: {
              ...state.generatedExtension,
              blocks: state.generatedExtension.blocks.map((b) =>
                b.id === blockId ? { ...b, enabled: !b.enabled } : b,
              ),
            },
          };
        }),

      updateBlockContent: (blockId, content) =>
        set((state) => {
          if (!state.generatedExtension) return state;
          return {
            generatedExtension: {
              ...state.generatedExtension,
              blocks: state.generatedExtension.blocks.map((b) =>
                b.id === blockId ? { ...b, content } : b,
              ),
            },
          };
        }),

      addBlock: (label, content) =>
        set((state) => {
          if (!state.generatedExtension) return state;
          return {
            generatedExtension: {
              ...state.generatedExtension,
              blocks: [
                ...state.generatedExtension.blocks,
                { id: nanoid(), label, content, enabled: true },
              ],
            },
          };
        }),

      removeBlock: (blockId) =>
        set((state) => {
          if (!state.generatedExtension) return state;
          return {
            generatedExtension: {
              ...state.generatedExtension,
              blocks: state.generatedExtension.blocks.filter(
                (b) => b.id !== blockId,
              ),
            },
          };
        }),

      reset: () => set({ generatedExtension: null, selectedFilePath: null }),
    }),
    {
      name: "scoria-extension",
      storage: createJSONStorage(() => sessionStorage),
    },
  ),
);
