import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { AppSettings, LLMProvider } from "@/types";
import { ALL_DATABASE_IDS } from "@/lib/databases";
import { encryptApiKey } from "@/lib/crypto";

interface SettingsState {
  settings: AppSettings;
  setActiveProvider: (provider: LLMProvider) => void;
  setApiKey: (provider: LLMProvider, plainKey: string) => Promise<void>;
  clearApiKey: (provider: LLMProvider) => void;
  setModel: (provider: LLMProvider, model: string) => void;
  toggleDatabase: (databaseId: string) => void;
  enableAllDatabases: () => void;
  disableAllDatabases: () => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      settings: {
        activeProvider: "anthropic",
        providers: {
          anthropic: {
            provider: "anthropic",
            model: "claude-sonnet-4-6",
            encryptedApiKey: null,
          },
          openai: {
            provider: "openai",
            model: "gpt-4o",
            encryptedApiKey: null,
          },
        },
        enabledDatabaseIds: [...ALL_DATABASE_IDS],
      },

      setActiveProvider: (provider) =>
        set((state) => ({
          settings: { ...state.settings, activeProvider: provider },
        })),

      setApiKey: async (provider, plainKey) => {
        const encrypted = await encryptApiKey(plainKey);
        set((state) => ({
          settings: {
            ...state.settings,
            providers: {
              ...state.settings.providers,
              [provider]: {
                ...state.settings.providers[provider],
                encryptedApiKey: encrypted,
              },
            },
          },
        }));
      },

      clearApiKey: (provider) =>
        set((state) => ({
          settings: {
            ...state.settings,
            providers: {
              ...state.settings.providers,
              [provider]: {
                ...state.settings.providers[provider],
                encryptedApiKey: null,
              },
            },
          },
        })),

      setModel: (provider, model) =>
        set((state) => ({
          settings: {
            ...state.settings,
            providers: {
              ...state.settings.providers,
              [provider]: {
                ...state.settings.providers[provider],
                model,
              },
            },
          },
        })),

      toggleDatabase: (databaseId) =>
        set((state) => {
          const ids = state.settings.enabledDatabaseIds;
          const next = ids.includes(databaseId)
            ? ids.filter((id) => id !== databaseId)
            : [...ids, databaseId];
          return {
            settings: { ...state.settings, enabledDatabaseIds: next },
          };
        }),

      enableAllDatabases: () =>
        set((state) => ({
          settings: {
            ...state.settings,
            enabledDatabaseIds: [...ALL_DATABASE_IDS],
          },
        })),

      disableAllDatabases: () =>
        set((state) => ({
          settings: { ...state.settings, enabledDatabaseIds: [] },
        })),
    }),
    { name: "scoria-settings" },
  ),
);
