import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { DEFAULT_AI_MODEL, type AiModelId } from "@/lib/ai/client";

/**
 * BYOK 設定（ADR-0027 / NFR-SEC-001）。
 *
 * API キーは localStorage のこのストアにのみ永続化する。履歴（scoria-history）や
 * 生成物には含めない。送信先は Anthropic API（src/lib/ai/client.ts）だけ。
 */
interface SettingsState {
  apiKey: string;
  aiModel: AiModelId;
  setApiKey: (key: string) => void;
  setAiModel: (model: AiModelId) => void;
  clearApiKey: () => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      apiKey: "",
      aiModel: DEFAULT_AI_MODEL,
      setApiKey: (key) => set({ apiKey: key.trim() }),
      setAiModel: (model) => set({ aiModel: model }),
      clearApiKey: () => set({ apiKey: "" }),
    }),
    {
      name: "scoria-settings",
      storage: createJSONStorage(() => localStorage),
    },
  ),
);
