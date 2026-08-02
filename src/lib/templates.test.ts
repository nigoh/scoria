import { describe, it, expect } from "vitest";
import { TEMPLATE_CONTENTS, TEMPLATE_CONTENTS_EN } from "./templates";
import type { TemplateMap } from "./templates";
import { TEMPLATES } from "./constants";
import { generateExtension } from "./generator";
import type { ExtensionFormData, ExtensionType, TemplateId } from "@/types";

const EXTENSION_TYPES: ExtensionType[] = ["skill", "agent", "plugin"];
const TEMPLATE_IDS = TEMPLATES.map((t) => t.id);

const MAPS: [string, TemplateMap][] = [
  ["ja", TEMPLATE_CONTENTS],
  ["en", TEMPLATE_CONTENTS_EN],
];

/**
 * テンプレートは 7 テンプレート × 3 拡張タイプ × 2 言語 = 42 通りの組み合わせを持つ。
 * 1件ずつ手で確かめるのは現実的でないので、全組み合わせを回して構造の不変条件を固定する
 * （`.claude/rules/tdd.md`: 組み合わせは直交表・全数で押さえる）。
 */
describe.each(MAPS)("TEMPLATE_CONTENTS (%s)", (lang, map) => {
  it("定数の TEMPLATES と過不足なく対応する", () => {
    expect(Object.keys(map).sort()).toEqual([...TEMPLATE_IDS].sort());
  });

  it.each(TEMPLATE_IDS)("%s: 3つの拡張タイプすべてを持つ", (id) => {
    expect(Object.keys(map[id]).sort()).toEqual([...EXTENSION_TYPES].sort());
  });

  it.each(TEMPLATE_IDS)("%s: どのタイプも名前・説明・ブロックが空でない", (id) => {
    for (const type of EXTENSION_TYPES) {
      const content = map[id][type];
      expect(content.defaultName, `${id}/${type} の defaultName`).not.toBe("");
      expect(content.defaultDescription, `${id}/${type} の defaultDescription`).not.toBe("");
      expect(content.blocks.length, `${id}/${type} のブロック数`).toBeGreaterThan(0);
      for (const block of content.blocks) {
        expect(block.label.trim(), `${id}/${type} のブロック見出し`).not.toBe("");
        expect(block.content.trim(), `${id}/${type} のブロック本文`).not.toBe("");
      }
    }
  });

  it.each(TEMPLATE_IDS)("%s: defaultName は生成パスに使える kebab-case", (id) => {
    // defaultName は .claude/skills/<name>/SKILL.md 等のパスにそのまま入る。
    // 空白や大文字・パス区切りが混じると生成物のパスが壊れる。
    for (const type of EXTENSION_TYPES) {
      expect(map[id][type].defaultName).toMatch(/^[a-z0-9]+(-[a-z0-9]+)*$/);
    }
  });

  it.each(TEMPLATE_IDS)("%s: ブロック見出しがタイプ内で重複しない", (id) => {
    // 見出しは生成物で `## <label>` になる。重複すると同じ節が二度出る。
    for (const type of EXTENSION_TYPES) {
      const labels = map[id][type].blocks.map((b) => b.label);
      expect(new Set(labels).size, `${id}/${type} の重複見出し`).toBe(labels.length);
    }
  });
});

describe("日本語版と英語版の対応", () => {
  it.each(TEMPLATE_IDS)("%s: 同じ拡張タイプを持ち、ブロック数が一致する", (id) => {
    for (const type of EXTENSION_TYPES) {
      expect(TEMPLATE_CONTENTS_EN[id][type].blocks.length).toBe(
        TEMPLATE_CONTENTS[id][type].blocks.length,
      );
    }
  });

  it.each(TEMPLATE_IDS)("%s: 英語版のブロック見出しに日本語が混ざらない", (id) => {
    for (const type of EXTENSION_TYPES) {
      for (const block of TEMPLATE_CONTENTS_EN[id][type].blocks) {
        expect(block.label, `${id}/${type}: ${block.label}`).not.toMatch(/[぀-ゟ゠-ヿ一-龯]/);
      }
    }
  });
});

const baseFormData: ExtensionFormData = {
  extensionType: null,
  templateId: null,
  name: "",
  description: "",
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

/**
 * テンプレートは単体で正しいだけでなく「生成まで通る」ことが要る。
 * 全 42 通りを実際に generateExtension へ通し、生成物の最低限の性質を確かめる。
 */
describe("全テンプレート × 全タイプ × 全言語の生成", () => {
  const cases: [TemplateId, ExtensionType, "ja" | "en"][] = [];
  for (const id of TEMPLATE_IDS) {
    for (const type of EXTENSION_TYPES) {
      for (const lang of ["ja", "en"] as const) cases.push([id, type, lang]);
    }
  }

  it.each(cases)("%s / %s / %s は空でないファイルを生成する", (templateId, extensionType, lang) => {
    const result = generateExtension({
      ...baseFormData,
      extensionType,
      templateId,
      outputLanguage: lang,
    });

    expect(result.files.length).toBeGreaterThan(0);
    for (const f of result.files) {
      expect(f.path, "パスが空").not.toBe("");
      expect(f.path.startsWith("/"), `${f.path} は絶対パス`).toBe(false);
      expect(f.path.includes(".."), `${f.path} に親参照が混ざる`).toBe(false);
      expect(f.content.trim(), `${f.path} の中身が空`).not.toBe("");
    }
  });

  it.each(cases)(
    "%s / %s / %s は同じパスのファイルを重複させない",
    (templateId, extensionType, lang) => {
      const result = generateExtension({
        ...baseFormData,
        extensionType,
        templateId,
        outputLanguage: lang,
      });

      const paths = result.files.map((f) => f.path);
      expect(new Set(paths).size).toBe(paths.length);
    },
  );
});
