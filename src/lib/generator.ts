import { nanoid } from "nanoid";
import type {
  ExtensionFormData,
  GeneratedExtension,
  GeneratedFile,
  ContentBlock,
} from "@/types";
import { TEMPLATE_CONTENTS } from "./templates";

export function generateExtension(formData: ExtensionFormData): GeneratedExtension {
  const { extensionType, templateId } = formData;
  if (!extensionType || !templateId) {
    throw new Error("拡張タイプとテンプレートを選択してください");
  }

  const template = TEMPLATE_CONTENTS[templateId][extensionType];
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

  const template = TEMPLATE_CONTENTS[templateId][extensionType];
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

  if (pluginConfig.includeSkills) {
    const skillBlock = enabledBlocks.find((b) => b.label === "スキル本文");
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
    const agentBlock = enabledBlocks.find((b) => b.label === "エージェント本文");
    const agentBody = agentBlock ? agentBlock.content : "";

    const frontmatter = [
      "---",
      `name: ${name}-agent`,
      `description: ${description}（エージェント）`,
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
    const claudeBlock = enabledBlocks.find((b) => b.label === "CLAUDE.md ガイド");
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

  return files;
}
