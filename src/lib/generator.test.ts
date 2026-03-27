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
    effort: null,
    context: "inline",
    agent: null,
    disableModelInvocation: false,
    paths: "",
    shell: "bash",
  },
  agentConfig: {
    tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"],
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
        ...baseFormData.pluginConfig,
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
    expect(paths).toContain("plugin.json");
    expect(paths).toContain("README.md");
  });

  it("plugin.jsonにメタデータが含まれる", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "plugin",
      templateId: "citation_check",
      name: "citation-check",
      description: "引用チェックプラグイン",
      pluginConfig: {
        ...baseFormData.pluginConfig,
        includePluginJson: true,
        pluginVersion: "2.0.0",
        pluginAuthor: "Test Author",
        pluginKeywords: "academic, citation",
      },
    };

    const result = generateExtension(formData);
    const pluginFile = result.files.find((f) => f.path === "plugin.json");
    expect(pluginFile).toBeTruthy();

    const parsed = JSON.parse(pluginFile!.content);
    expect(parsed.name).toBe("citation-check");
    expect(parsed.version).toBe("2.0.0");
    expect(parsed.author.name).toBe("Test Author");
    expect(parsed.keywords).toEqual(["academic", "citation"]);
    expect(parsed.skills).toBe("./skills/");
  });

  it("README.mdが生成される", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "plugin",
      templateId: "citation_check",
      name: "citation-check",
      description: "引用チェックプラグイン",
      pluginConfig: {
        ...baseFormData.pluginConfig,
        includeReadme: true,
      },
    };

    const result = generateExtension(formData);
    const readme = result.files.find((f) => f.path === "README.md");
    expect(readme).toBeTruthy();
    expect(readme!.content).toContain("# citation-check");
    expect(readme!.content).toContain("引用チェックプラグイン");
    expect(readme!.content).toContain("claude plugin install");
  });

  it("拡張タイプ未選択の場合はエラーを投げる", () => {
    expect(() => generateExtension(baseFormData)).toThrow(
      "拡張タイプとテンプレートを選択してください",
    );
  });

  it("スキルの詳細frontmatterフィールドが出力される", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "skill",
      templateId: "systematic_review",
      name: "my-skill",
      description: "テスト",
      skillConfig: {
        ...baseFormData.skillConfig,
        effort: "high",
        context: "fork",
        agent: "Explore",
        disableModelInvocation: true,
        paths: "src/**/*.ts",
        shell: "powershell",
      },
    };

    const result = generateExtension(formData);
    const content = result.files[0].content;

    expect(content).toContain("effort: high");
    expect(content).toContain("context: fork");
    expect(content).toContain("agent: Explore");
    expect(content).toContain("disable-model-invocation: true");
    expect(content).toContain("paths: src/**/*.ts");
    expect(content).toContain("shell: powershell");
  });

  it("エージェントの詳細frontmatterフィールドが出力される", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "agent",
      templateId: "meta_analysis",
      name: "my-agent",
      description: "テスト",
      agentConfig: {
        ...baseFormData.agentConfig,
        effort: "medium",
        disallowedTools: ["Write", "Edit"],
        skills: "my-skill",
        isolation: "worktree",
      },
    };

    const result = generateExtension(formData);
    const content = result.files[0].content;

    expect(content).toContain("effort: medium");
    expect(content).toContain("disallowedTools: Write, Edit");
    expect(content).toContain("skills: my-skill");
    expect(content).toContain("isolation: worktree");
  });

  it("デフォルト値の場合、詳細フィールドは出力されない", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "skill",
      templateId: "systematic_review",
      name: "my-skill",
      description: "テスト",
    };

    const result = generateExtension(formData);
    const content = result.files[0].content;

    expect(content).not.toContain("effort:");
    expect(content).not.toContain("context:");
    expect(content).not.toContain("agent:");
    expect(content).not.toContain("disable-model-invocation:");
    expect(content).not.toContain("paths:");
    expect(content).not.toContain("shell:");
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

describe("generateExtension (English)", () => {
  it("英語出力の場合、英語テンプレートが使用される", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "skill",
      templateId: "systematic_review",
      name: "systematic-review",
      description: "Conduct PRISMA-compliant reviews",
      outputLanguage: "en",
    };

    const result = generateExtension(formData);

    expect(result.files[0].content).toContain("name: systematic-review");
    expect(result.blocks[0].label).toBe("Role Definition");
    expect(result.blocks[0].content).toContain("PRISMA 2020");
  });

  it("英語プラグインのラベルマッチングが動作する", () => {
    const formData: ExtensionFormData = {
      ...baseFormData,
      extensionType: "plugin",
      templateId: "citation_check",
      name: "citation-check",
      description: "Citation check plugin",
      outputLanguage: "en",
      pluginConfig: {
        ...baseFormData.pluginConfig,
        includeSkills: true,
        includeAgents: true,
        includeHooks: false,
        includeClaudeMd: true,
        includeMcp: false,
      },
    };

    const result = generateExtension(formData);

    const skillFile = result.files.find((f) => f.path.includes("SKILL.md"));
    expect(skillFile?.content).toContain("citation");

    const claudeFile = result.files.find((f) => f.path === "CLAUDE.md");
    expect(claudeFile?.content).toBeTruthy();
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
