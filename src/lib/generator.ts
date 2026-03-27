import { nanoid } from "nanoid";
import type {
  ExtensionFormData,
  GeneratedExtension,
  GeneratedFile,
  ContentBlock,
} from "@/types";
import { TEMPLATE_CONTENTS, TEMPLATE_CONTENTS_EN } from "./templates";

function getTemplateMap(lang: "ja" | "en") {
  return lang === "en" ? TEMPLATE_CONTENTS_EN : TEMPLATE_CONTENTS;
}

export function generateExtension(formData: ExtensionFormData): GeneratedExtension {
  const { extensionType, templateId } = formData;
  if (!extensionType || !templateId) {
    throw new Error("拡張タイプとテンプレートを選択してください");
  }

  const templateMap = getTemplateMap(formData.outputLanguage);
  const template = templateMap[templateId][extensionType];
  const name = formData.name || template.defaultName;
  const description = formData.description || template.defaultDescription;

  const blocks: ContentBlock[] = template.blocks.map((b) => ({
    id: nanoid(),
    label: b.label,
    content: b.content,
    enabled: true,
  }));

  const files = buildFiles(formData, name, description, blocks);

  return {
    files,
    blocks,
    generatedAt: new Date().toISOString(),
  };
}

export function regenerateFiles(
  formData: ExtensionFormData,
  blocks: ContentBlock[],
): GeneratedFile[] {
  const { extensionType, templateId } = formData;
  if (!extensionType || !templateId) return [];

  const templateMap = getTemplateMap(formData.outputLanguage);
  const template = templateMap[templateId][extensionType];
  const name = formData.name || template.defaultName;
  const description = formData.description || template.defaultDescription;

  return buildFiles(formData, name, description, blocks);
}

function buildFiles(
  formData: ExtensionFormData,
  name: string,
  description: string,
  blocks: ContentBlock[],
): GeneratedFile[] {
  const { extensionType } = formData;
  const enabledContent = blocks
    .filter((b) => b.enabled)
    .map((b) => `## ${b.label}\n${b.content}`)
    .join("\n\n");

  switch (extensionType) {
    case "skill":
      return buildSkillFiles(formData, name, description, enabledContent);
    case "agent":
      return buildAgentFiles(formData, name, description, enabledContent);
    case "plugin":
      return buildPluginFiles(formData, name, description, blocks);
    default:
      return [];
  }
}

function buildSkillFiles(
  formData: ExtensionFormData,
  name: string,
  description: string,
  body: string,
): GeneratedFile[] {
  const { skillConfig } = formData;
  const frontmatter = [
    "---",
    `name: ${name}`,
    `description: ${description}`,
  ];

  if (skillConfig.argumentHint) {
    frontmatter.push(`argument-hint: ${skillConfig.argumentHint}`);
  }
  if (skillConfig.allowedTools.length > 0) {
    frontmatter.push(`allowed-tools: ${skillConfig.allowedTools.join(", ")}`);
  }
  if (skillConfig.model !== "inherit") {
    frontmatter.push(`model: ${skillConfig.model}`);
  }
  frontmatter.push(`user-invocable: ${skillConfig.userInvocable}`);
  if (skillConfig.effort) {
    frontmatter.push(`effort: ${skillConfig.effort}`);
  }
  if (skillConfig.context !== "inline") {
    frontmatter.push(`context: ${skillConfig.context}`);
  }
  if (skillConfig.agent) {
    frontmatter.push(`agent: ${skillConfig.agent}`);
  }
  if (skillConfig.disableModelInvocation) {
    frontmatter.push("disable-model-invocation: true");
  }
  if (skillConfig.paths) {
    frontmatter.push(`paths: ${skillConfig.paths}`);
  }
  if (skillConfig.shell !== "bash") {
    frontmatter.push(`shell: ${skillConfig.shell}`);
  }
  frontmatter.push("---");

  const content = `${frontmatter.join("\n")}\n\n${body}\n`;

  return [
    {
      path: `.claude/skills/${name}/SKILL.md`,
      content,
      language: "markdown",
    },
  ];
}

function buildAgentFiles(
  formData: ExtensionFormData,
  name: string,
  description: string,
  body: string,
): GeneratedFile[] {
  const { agentConfig } = formData;
  const frontmatter = [
    "---",
    `name: ${name}`,
    `description: ${description}`,
  ];

  if (agentConfig.tools.length > 0) {
    frontmatter.push(`tools: ${agentConfig.tools.join(", ")}`);
  }
  if (agentConfig.model !== "inherit") {
    frontmatter.push(`model: ${agentConfig.model}`);
  }
  frontmatter.push(`maxTurns: ${agentConfig.maxTurns}`);
  if (agentConfig.effort) {
    frontmatter.push(`effort: ${agentConfig.effort}`);
  }
  if (agentConfig.disallowedTools.length > 0) {
    frontmatter.push(`disallowedTools: ${agentConfig.disallowedTools.join(", ")}`);
  }
  if (agentConfig.skills) {
    frontmatter.push(`skills: ${agentConfig.skills}`);
  }
  if (agentConfig.isolation !== "none") {
    frontmatter.push(`isolation: ${agentConfig.isolation}`);
  }
  frontmatter.push("---");

  const content = `${frontmatter.join("\n")}\n\n${body}\n`;

  return [
    {
      path: `.claude/agents/${name}.md`,
      content,
      language: "markdown",
    },
  ];
}

function buildPluginFiles(
  formData: ExtensionFormData,
  name: string,
  description: string,
  blocks: ContentBlock[],
): GeneratedFile[] {
  const { pluginConfig, skillConfig, agentConfig } = formData;
  const files: GeneratedFile[] = [];

  const enabledBlocks = blocks.filter((b) => b.enabled);
  const SKILL_BODY_LABELS = ["スキル本文", "Skill Body"];
  const AGENT_BODY_LABELS = ["エージェント本文", "Agent Body"];
  const CLAUDE_MD_LABELS = ["CLAUDE.md ガイド", "CLAUDE.md Guide"];

  if (pluginConfig.includeSkills) {
    const skillBlock = enabledBlocks.find((b) => SKILL_BODY_LABELS.includes(b.label));
    const skillBody = skillBlock ? `## 指示内容\n${skillBlock.content}` : "";

    const frontmatter = [
      "---",
      `name: ${name}`,
      `description: ${description}`,
    ];
    if (skillConfig.allowedTools.length > 0) {
      frontmatter.push(`allowed-tools: ${skillConfig.allowedTools.join(", ")}`);
    }
    if (skillConfig.model !== "inherit") {
      frontmatter.push(`model: ${skillConfig.model}`);
    }
    frontmatter.push("user-invocable: true");
    frontmatter.push("---");

    files.push({
      path: `skills/${name}/SKILL.md`,
      content: `${frontmatter.join("\n")}\n\n${skillBody}\n`,
      language: "markdown",
    });
  }

  if (pluginConfig.includeAgents) {
    const agentBlock = enabledBlocks.find((b) => AGENT_BODY_LABELS.includes(b.label));
    const agentBody = agentBlock ? agentBlock.content : "";

    const frontmatter = [
      "---",
      `name: ${name}-agent`,
      `description: ${description}${formData.outputLanguage === "en" ? " (Agent)" : "（エージェント）"}`,
    ];
    if (agentConfig.tools.length > 0) {
      frontmatter.push(`tools: ${agentConfig.tools.join(", ")}`);
    }
    if (agentConfig.model !== "inherit") {
      frontmatter.push(`model: ${agentConfig.model}`);
    }
    frontmatter.push(`maxTurns: ${agentConfig.maxTurns}`);
    frontmatter.push("---");

    files.push({
      path: `agents/${name}-agent.md`,
      content: `${frontmatter.join("\n")}\n\n${agentBody}\n`,
      language: "markdown",
    });
  }

  if (pluginConfig.includeHooks) {
    const hooks = {
      hooks: {
        PostToolUse: [
          {
            matcher: "Edit|Write",
            hooks: [
              {
                type: "command",
                command: `echo "File modified by ${name} plugin"`,
              },
            ],
          },
        ],
      },
    };
    files.push({
      path: "hooks/hooks.json",
      content: JSON.stringify(hooks, null, 2) + "\n",
      language: "json",
    });
  }

  if (pluginConfig.includeClaudeMd) {
    const claudeBlock = enabledBlocks.find((b) => CLAUDE_MD_LABELS.includes(b.label));
    const claudeContent = claudeBlock ? claudeBlock.content : `# ${name}\n\n${description}`;
    files.push({
      path: "CLAUDE.md",
      content: claudeContent + "\n",
      language: "markdown",
    });
  }

  if (pluginConfig.includeMcp) {
    const mcp = {
      mcpServers: {},
    };
    files.push({
      path: ".mcp.json",
      content: JSON.stringify(mcp, null, 2) + "\n",
      language: "json",
    });
  }

  if (pluginConfig.includePluginJson) {
    const pluginJson: Record<string, unknown> = {
      name,
      version: pluginConfig.pluginVersion || "1.0.0",
      description,
    };
    if (pluginConfig.pluginAuthor) {
      pluginJson.author = { name: pluginConfig.pluginAuthor };
    }
    if (pluginConfig.pluginKeywords) {
      pluginJson.keywords = pluginConfig.pluginKeywords
        .split(",")
        .map((k) => k.trim())
        .filter(Boolean);
    }
    if (pluginConfig.includeSkills) pluginJson.skills = "./skills/";
    if (pluginConfig.includeAgents) pluginJson.agents = "./agents/";
    if (pluginConfig.includeHooks) pluginJson.hooks = "./hooks/hooks.json";
    if (pluginConfig.includeMcp) pluginJson.mcpServers = "./.mcp.json";

    files.push({
      path: "plugin.json",
      content: JSON.stringify(pluginJson, null, 2) + "\n",
      language: "json",
    });
  }

  if (pluginConfig.includeReadme) {
    const isEn = formData.outputLanguage === "en";
    const sections: string[] = [`# ${name}`, "", description, ""];

    sections.push(isEn ? "## Installation" : "## インストール");
    sections.push("```bash");
    sections.push(`claude plugin install ./${name}`);
    sections.push("```", "");

    sections.push(isEn ? "## Components" : "## コンポーネント");
    if (pluginConfig.includeSkills) sections.push(`- Skills: \`skills/\``);
    if (pluginConfig.includeAgents) sections.push(`- Agents: \`agents/\``);
    if (pluginConfig.includeHooks) sections.push(`- Hooks: \`hooks/\``);
    if (pluginConfig.includeClaudeMd) sections.push(`- CLAUDE.md`);
    if (pluginConfig.includeMcp) sections.push(`- MCP: \`.mcp.json\``);
    sections.push("");

    sections.push(isEn ? "## Usage" : "## 使い方");
    sections.push("```");
    sections.push(`/${name} ${formData.skillConfig.argumentHint || "[arguments]"}`);
    sections.push("```", "");

    files.push({
      path: "README.md",
      content: sections.join("\n"),
      language: "markdown",
    });
  }

  return files;
}
