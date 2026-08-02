import { describe, it, expect } from "vitest";
import {
  EXTENSION_TYPES,
  TEMPLATES,
  CLAUDE_TOOLS,
  EFFORT_OPTIONS,
  HOOK_EVENTS,
  HOOK_TYPES,
  HOOK_PRESETS,
  MCP_TEMPLATES,
  MODEL_OPTIONS,
  RESEARCH_FIELDS,
  WIZARD_STEP_LABELS,
} from "./constants";

/**
 * 定数はウィザードの選択肢そのものなので、重複・空ラベル・型の食い違いがそのまま
 * 「選べない選択肢」「同じ項目が2つ出る」といった不具合になる。一覧に共通する不変条件を固定する。
 */

const LABELLED = [
  ["EXTENSION_TYPES", EXTENSION_TYPES],
  ["TEMPLATES", TEMPLATES],
  ["EFFORT_OPTIONS", EFFORT_OPTIONS as readonly { labelJa: string; labelEn: string }[]],
  ["HOOK_PRESETS", HOOK_PRESETS],
  ["MCP_TEMPLATES", MCP_TEMPLATES],
  ["MODEL_OPTIONS", MODEL_OPTIONS],
  ["RESEARCH_FIELDS", RESEARCH_FIELDS],
] as const;

describe.each(LABELLED)("%s", (name, list) => {
  it("空でない", () => {
    expect(list.length).toBeGreaterThan(0);
  });

  it("日本語ラベルと英語ラベルがどちらも空でない", () => {
    for (const item of list) {
      expect(item.labelJa.trim(), `${name} の labelJa`).not.toBe("");
      expect(item.labelEn.trim(), `${name} の labelEn`).not.toBe("");
    }
  });
});

const WITH_ID = [
  ["EXTENSION_TYPES", EXTENSION_TYPES],
  ["TEMPLATES", TEMPLATES],
  ["MODEL_OPTIONS", MODEL_OPTIONS],
  ["RESEARCH_FIELDS", RESEARCH_FIELDS],
] as const;

describe.each(WITH_ID)("%s の id", (name, list) => {
  it("重複しない", () => {
    const ids = list.map((i) => i.id);
    expect(new Set(ids).size, `${name} に重複 id`).toBe(ids.length);
  });
});

describe("EXTENSION_TYPES", () => {
  it("skill / agent / plugin の3種を過不足なく持つ", () => {
    expect(EXTENSION_TYPES.map((t) => t.id).sort()).toEqual(["agent", "plugin", "skill"]);
  });

  it("すべてアイコン名を持つ", () => {
    for (const t of EXTENSION_TYPES) expect(t.icon).not.toBe("");
  });
});

describe("TEMPLATES", () => {
  it("supportedTypes が空のテンプレートは無い（選んでも進めなくなる）", () => {
    for (const t of TEMPLATES) {
      expect(t.supportedTypes.length, `${t.id} の supportedTypes`).toBeGreaterThan(0);
    }
  });

  it("supportedTypes は既知の拡張タイプだけを含む", () => {
    const known = new Set(EXTENSION_TYPES.map((t) => t.id));
    for (const t of TEMPLATES) {
      for (const type of t.supportedTypes) {
        expect(known.has(type), `${t.id} の未知タイプ ${type}`).toBe(true);
      }
    }
  });

  it("自由記述用の custom を含む", () => {
    expect(TEMPLATES.map((t) => t.id)).toContain("custom");
  });
});

describe("重複しない語彙リスト", () => {
  it.each([
    ["CLAUDE_TOOLS", CLAUDE_TOOLS],
    ["HOOK_EVENTS", HOOK_EVENTS],
    ["HOOK_TYPES", HOOK_TYPES],
  ] as const)("%s に重複が無い", (_name, list) => {
    expect(new Set(list).size).toBe(list.length);
  });

  it("CLAUDE_TOOLS に空文字が混ざらない", () => {
    for (const tool of CLAUDE_TOOLS) expect(tool.trim()).not.toBe("");
  });
});

describe("HOOK_PRESETS", () => {
  it("event は HOOK_EVENTS に載っているものだけ", () => {
    const known = new Set<string>(HOOK_EVENTS);
    for (const preset of HOOK_PRESETS) {
      expect(known.has(preset.event), `未知のイベント ${preset.event}`).toBe(true);
    }
  });

  it("hookType は HOOK_TYPES に載っているものだけ", () => {
    const known = new Set<string>(HOOK_TYPES);
    for (const preset of HOOK_PRESETS) {
      expect(known.has(preset.hookType), `未知の種別 ${preset.hookType}`).toBe(true);
    }
  });

  it("command 型のプリセットは実行内容を持つ", () => {
    for (const preset of HOOK_PRESETS.filter((p) => p.hookType === "command")) {
      expect(preset.command.trim(), `${preset.labelJa} の command`).not.toBe("");
    }
  });
});

describe("MCP_TEMPLATES", () => {
  it("サーバー名は設定キーに使えるので空でなく重複しない", () => {
    const names = MCP_TEMPLATES.map((m) => m.name);
    for (const n of names) expect(n.trim()).not.toBe("");
    expect(new Set(names).size).toBe(names.length);
  });

  it("カスタム以外は起動コマンドを持つ", () => {
    for (const m of MCP_TEMPLATES.filter((t) => t.name !== "my-server")) {
      expect(m.command.trim(), `${m.name} の command`).not.toBe("");
    }
  });
});

describe("MODEL_OPTIONS", () => {
  it("inherit を含む（継承を選べないと agent 設定が作れない）", () => {
    expect(MODEL_OPTIONS.map((m) => m.id)).toContain("inherit");
  });
});

describe("WIZARD_STEP_LABELS", () => {
  it("4ステップすべてにラベルがある", () => {
    expect(Object.keys(WIZARD_STEP_LABELS).sort()).toEqual(["1", "2", "3", "4"]);
    for (const label of Object.values(WIZARD_STEP_LABELS)) expect(label.trim()).not.toBe("");
  });
});
