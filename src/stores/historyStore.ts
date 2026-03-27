import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { nanoid } from "nanoid";
import type { ExtensionFormData, ContentBlock, HistoryEntry } from "@/types";

const MAX_ENTRIES = 20;

interface HistoryState {
  entries: HistoryEntry[];
  saveEntry: (
    formData: ExtensionFormData,
    blocks: ContentBlock[],
    generatedAt: string,
  ) => void;
  deleteEntry: (id: string) => void;
  clearAll: () => void;
}

export const useHistoryStore = create<HistoryState>()(
  persist(
    (set) => ({
      entries: [],

      saveEntry: (formData, blocks, generatedAt) =>
        set((state) => {
          const entry: HistoryEntry = {
            id: nanoid(),
            name: formData.name || "untitled",
            extensionType: formData.extensionType!,
            templateId: formData.templateId!,
            formData,
            blocks,
            generatedAt,
            savedAt: new Date().toISOString(),
          };

          const updated = [entry, ...state.entries];
          if (updated.length > MAX_ENTRIES) {
            updated.length = MAX_ENTRIES;
          }
          return { entries: updated };
        }),

      deleteEntry: (id) =>
        set((state) => ({
          entries: state.entries.filter((e) => e.id !== id),
        })),

      clearAll: () => set({ entries: [] }),
    }),
    {
      name: "scoria-history",
      storage: createJSONStorage(() => localStorage),
    },
  ),
);
