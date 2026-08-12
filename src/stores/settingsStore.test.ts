import { describe, it, expect, beforeEach } from "vitest";
import { installMemoryStorage } from "./testStorage";

installMemoryStorage();

const { useSettingsStore } = await import("./settingsStore");
const { useHistoryStore } = await import("./historyStore");
import type { ExtensionFormData } from "@/types";

// Verifies: NFR-SEC-001

const store = () => useSettingsStore.getState();
const SECRET = "sk-ant-api03-super-secret-key";

function formData(): ExtensionFormData {
  return {
    extensionType: "skill",
    templateId: "custom",
    name: "ai-made",
    description: "説明",
    outputLanguage: "ja",
    skillConfig: {
      argumentHint: "",
      allowedTools: ["Read"],
      model: "sonnet",
      userInvocable: true,
      effort: null,
      context: "inline",
      agent: null,
      disableModelInvocation: false,
      paths: "",
      shell: "bash",
    },
    agentConfig: {
      tools: ["Read"],
      model: "sonnet",
      maxTurns: 30,
      researchField: null,
      effort: null,
      disallowedTools: [],
      skills: "",
      isolation: "none",
    },
    pluginConfig: {
      includeSkills: true,
      includeAgents: true,
      includeHooks: false,
      includeClaudeMd: true,
      includeMcp: false,
      includePluginJson: true,
      includeReadme: true,
      pluginVersion: "1.0.0",
      pluginAuthor: "",
      pluginKeywords: "",
    },
    hookEntries: [],
    mcpEntries: [],
  };
}

beforeEach(() => {
  store().clearApiKey();
  store().setAiModel("claude-opus-5");
  useHistoryStore.getState().clearAll();
});

describe("設定の保存", () => {
  it("キーは前後の空白を落として保存される", () => {
    store().setApiKey(`  ${SECRET}  `);
    expect(store().apiKey).toBe(SECRET);
  });

  it("モデルの既定は claude-opus-5", () => {
    expect(store().aiModel).toBe("claude-opus-5");
  });

  it("clearApiKey でキーだけ消える（モデル設定は残る）", () => {
    store().setApiKey(SECRET);
    store().setAiModel("claude-haiku-4-5");
    store().clearApiKey();

    expect(store().apiKey).toBe("");
    expect(store().aiModel).toBe("claude-haiku-4-5");
  });
});

describe("キーの隔離（NFR-SEC-001）", () => {
  it("キーは scoria-settings にのみ永続化され、履歴のストレージには現れない", () => {
    store().setApiKey(SECRET);
    useHistoryStore
      .getState()
      .saveEntry(
        formData(),
        [{ id: "b1", label: "手順", content: "x", enabled: true }],
        "2026-08-02T00:00:00.000Z",
      );

    const settingsRaw = localStorage.getItem("scoria-settings") ?? "";
    const historyRaw = localStorage.getItem("scoria-history") ?? "";

    expect(settingsRaw).toContain(SECRET);
    expect(historyRaw).not.toContain(SECRET);
    // 履歴エントリのオブジェクトにも混ざらない
    expect(JSON.stringify(useHistoryStore.getState().entries)).not.toContain(SECRET);
  });
});
