import { describe, it, expect } from "vitest";
import { generateExtension, regenerateFiles } from "./generator";
import type { ExtensionFormData } from "@/types";

const baseFormData: ExtensionFormData = {
  extensionType: null,
  templateId: null,
  name: "",
  description: "",
  outputLanguage: "ja",
  skillConfig: {
    argumentHint: "[研究テーマ]",
    allowedTools: ["Read", "Grep", "Glob"],
    model: "sonnet",
    userInvocable: true,
  },
  agentConfig: {
    tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"],
    model: "sonnet",
    maxTurns: 30,
    researchField: null,
  },
  pluginConfig: {
    includeSkills: true,
    includeAgents: true,
    includeHooks: false,
    includeClaudeMd: true,
    includeMcp: false,
  },
};

describe("generateExtension", () => {
  it("スキルタイプの場合、SKILL.mdファイルを生成する", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "skill",
      templateId: "systematic_review",
      name: "systematic-review",
      description: "PRISMA準拠の系統的文献レビューを実行する",
    };

    const result = generateExtension(formData);

    expect(result.files).toHaveLength(1);
    expect(result.files[0].path).toBe(".claude/skills/systematic-review/SKILL.md");
    expect(result.files[0].content).toContain("name: systematic-review");
    expect(result.files[0].content).toContain("allowed-tools: Read, Grep, Glob");
    expect(result.files[0].content).toContain("model: sonnet");
    expect(result.blocks.length).toBeGreaterThan(0);
    expect(result.generatedAt).toBeTruthy();
  });

  it("エージェントタイプの場合、agent.mdファイルを生成する", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "agent",
      templateId: "meta_analysis",
      name: "meta-analysis-agent",
      description: "メタ分析を自律的に支援するエージェント",
    };

    const result = generateExtension(formData);

    expect(result.files).toHaveLength(1);
    expect(result.files[0].path).toBe(".claude/agents/meta-analysis-agent.md");
    expect(result.files[0].content).toContain("name: meta-analysis-agent");
    expect(result.files[0].content).toContain("maxTurns: 30");
  });

  it("プラグインタイプの場合、複数ファイルを生成する", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "plugin",
      templateId: "citation_check",
      name: "citation-check",
      description: "引用チェックプラグイン",
      pluginConfig: {
        includeSkills: true,
        includeAgents: true,
        includeHooks: true,
        includeClaudeMd: true,
        includeMcp: false,
      },
    };

    const result = generateExtension(formData);

    const paths = result.files.map((f) => f.path);
    expect(paths).toContain("skills/citation-check/SKILL.md");
    expect(paths).toContain("agents/citation-check-agent.md");
    expect(paths).toContain("hooks/hooks.json");
    expect(paths).toContain("CLAUDE.md");
    expect(paths).not.toContain(".mcp.json");
  });

  it("拡張タイプ未選択の場合はエラーを投げる", () => {
    expect(() => generateExtension(baseFormData)).toThrow(
      "拡張タイプとテンプレートを選択してください",
    );
  });

  it("テンプレート未選択時にデフォルト名を使用する", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "skill",
      templateId: "custom",
      name: "",
      description: "",
    };

    const result = generateExtension(formData);

    expect(result.files[0].path).toContain("my-skill");
  });
});

describe("regenerateFiles", () => {
  it("ブロック内容の変更がファイルに反映される", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "skill",
      templateId: "systematic_review",
      name: "systematic-review",
      description: "テスト",
    };

    const initial = generateExtension(formData);
    const modifiedBlocks = initial.blocks.map((b) =>
      b.label === "役割設定" ? { ...b, content: "カスタム役割の内容" } : b,
    );

    const files = regenerateFiles(formData, modifiedBlocks);

    expect(files[0].content).toContain("カスタム役割の内容");
  });
});
