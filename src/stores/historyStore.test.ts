import { describe, it, expect, beforeEach } from "vitest";
import { installMemoryStorage } from "./testStorage";

installMemoryStorage();

const { useHistoryStore } = await import("./historyStore");
import type { ExtensionFormData, ContentBlock } from "@/types";

const store = () => useHistoryStore.getState();

const blocks: ContentBlock[] = [{ id: "b1", label: "手順", content: "1. やる", enabled: true }];

function formData(name: string): ExtensionFormData {
  return {
    extensionType: "skill",
    templateId: "repro_review",
    name,
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

const save = (name: string) =>
  store().saveEntry(formData(name), blocks, "2026-08-02T00:00:00.000Z");

beforeEach(() => {
  store().clearAll();
});

describe("saveEntry", () => {
  it("保存した内容を取り出せる", () => {
    save("my-skill");
    const [entry] = store().entries;

    expect(entry.name).toBe("my-skill");
    expect(entry.extensionType).toBe("skill");
    expect(entry.templateId).toBe("repro_review");
    expect(entry.blocks).toEqual(blocks);
    expect(entry.generatedAt).toBe("2026-08-02T00:00:00.000Z");
  });

  it("新しいものが先頭に来る", () => {
    save("first");
    save("second");

    expect(store().entries.map((e) => e.name)).toEqual(["second", "first"]);
  });

  it("名前が空なら untitled にする", () => {
    save("");

    expect(store().entries[0].name).toBe("untitled");
  });

  it("エントリごとに異なる id を振る", () => {
    save("a");
    save("a");
    const ids = store().entries.map((e) => e.id);

    expect(new Set(ids).size).toBe(2);
  });

  it("保存時刻を記録する", () => {
    save("a");

    expect(() => new Date(store().entries[0].savedAt).toISOString()).not.toThrow();
  });
});

describe("上限（20件）", () => {
  it("21件目を保存しても20件を超えない", () => {
    for (let i = 0; i < 21; i += 1) save(`entry-${i}`);

    expect(store().entries).toHaveLength(20);
  });

  it("あふれたときに落ちるのは最も古いエントリ", () => {
    for (let i = 0; i < 21; i += 1) save(`entry-${i}`);
    const names = store().entries.map((e) => e.name);

    expect(names[0]).toBe("entry-20");
    expect(names).not.toContain("entry-0");
    expect(names).toContain("entry-1");
  });

  it("上限に達したあとも保存し続けられる", () => {
    for (let i = 0; i < 30; i += 1) save(`entry-${i}`);

    expect(store().entries).toHaveLength(20);
    expect(store().entries[0].name).toBe("entry-29");
  });
});

describe("deleteEntry", () => {
  it("指定した1件だけを消す", () => {
    save("a");
    save("b");
    save("c");
    const target = store().entries.find((e) => e.name === "b")!;

    store().deleteEntry(target.id);

    expect(store().entries.map((e) => e.name)).toEqual(["c", "a"]);
  });

  it("存在しない id では何も消さない", () => {
    save("a");
    store().deleteEntry("nope");

    expect(store().entries).toHaveLength(1);
  });
});

describe("clearAll", () => {
  it("すべて消す", () => {
    save("a");
    save("b");
    store().clearAll();

    expect(store().entries).toEqual([]);
  });
});
