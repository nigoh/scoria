import { describe, it, expect } from "vitest";
import { applyAiDesign } from "./design";
import type { AiDesignResult, ExtensionFormData } from "@/types";

// Verifies: REQ-AI-003

const baseFormData: ExtensionFormData = {
  extensionType: "skill",
  templateId: null,
  name: "",
  description: "",
  outputLanguage: "ja",
  skillConfig: {
    argumentHint: "[研究テーマ]",
    allowedTools: ["Read", "Grep"],
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

const design: AiDesignResult = {
  name: "grounded-theory-coding",
  description: "グラウンデッド・セオリーのコーディングを支援する",
  blocks: [
    { label: "オープンコーディング", content: "データを断片化して概念を付与する" },
    { label: "軸足コーディング", content: "概念をカテゴリに束ねる" },
  ],
};

describe("applyAiDesign", () => {
  it("ファイルは決定論ジェネレータで組み立てられ、frontmatter の name が AI の name と一致する", () => {
    const { extension } = applyAiDesign(baseFormData, design);

    expect(extension.files).toHaveLength(1);
    const file = extension.files[0];
    expect(file.path).toBe(".claude/skills/grounded-theory-coding/SKILL.md");
    expect(file.content).toContain("name: grounded-theory-coding");
    expect(file.content).toContain("description: グラウンデッド・セオリーのコーディングを支援する");
    // 既存 skillConfig（決定論側の設定）も反映される
    expect(file.content).toContain("allowed-tools: Read, Grep");
  });

  it("AI の blocks はすべて有効状態の編集可能ブロックになる", () => {
    const { extension } = applyAiDesign(baseFormData, design);

    expect(extension.blocks).toHaveLength(2);
    for (const b of extension.blocks) {
      expect(b.enabled).toBe(true);
      expect(b.id).not.toBe("");
    }
    // ブロック本文がファイルに節として入る
    expect(extension.files[0].content).toContain("## オープンコーディング");
  });

  it("formData には templateId=custom と AI の name/description が反映される", () => {
    const { formData } = applyAiDesign(baseFormData, design);

    expect(formData.templateId).toBe("custom");
    expect(formData.name).toBe("grounded-theory-coding");
    expect(formData.description).toBe(design.description);
    // 元の formData は変異しない
    expect(baseFormData.templateId).toBeNull();
  });

  it("エージェントでも同じ経路で組み立てられる", () => {
    const { extension } = applyAiDesign({ ...baseFormData, extensionType: "agent" }, design);

    expect(extension.files[0].path).toBe(".claude/agents/grounded-theory-coding.md");
    expect(extension.files[0].content).toContain("name: grounded-theory-coding");
  });
});
