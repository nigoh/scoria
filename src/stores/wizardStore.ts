import { create } from "zustand";
import type {
  ExtensionType,
  TemplateId,
  WizardStep,
  ExtensionFormData,
  ModelChoice,
  EffortLevel,
  PluginConfig,
} from "@/types";

type BooleanPluginKey = {
  [K in keyof PluginConfig]: PluginConfig[K] extends boolean ? K : never;
}[keyof PluginConfig];

const initialFormData: ExtensionFormData = {
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

interface WizardState {
  currentStep: WizardStep;
  formData: ExtensionFormData;
  setStep: (step: WizardStep) => void;
  nextStep: () => void;
  prevStep: () => void;
  setExtensionType: (type: ExtensionType) => void;
  setTemplateId: (id: TemplateId) => void;
  setName: (name: string) => void;
  setDescription: (description: string) => void;
  setOutputLanguage: (lang: "ja" | "en") => void;
  setSkillArgumentHint: (hint: string) => void;
  setSkillAllowedTools: (tools: string[]) => void;
  setSkillModel: (model: ModelChoice) => void;
  setSkillUserInvocable: (v: boolean) => void;
  setSkillEffort: (effort: EffortLevel | null) => void;
  setSkillContext: (context: "inline" | "fork") => void;
  setSkillAgent: (agent: string | null) => void;
  setSkillDisableModelInvocation: (v: boolean) => void;
  setSkillPaths: (paths: string) => void;
  setSkillShell: (shell: "bash" | "powershell") => void;
  setAgentTools: (tools: string[]) => void;
  setAgentModel: (model: ModelChoice) => void;
  setAgentMaxTurns: (turns: number) => void;
  setAgentResearchField: (field: string | null) => void;
  setAgentEffort: (effort: EffortLevel | null) => void;
  setAgentDisallowedTools: (tools: string[]) => void;
  setAgentSkills: (skills: string) => void;
  setAgentIsolation: (isolation: "none" | "worktree") => void;
  togglePluginComponent: (key: BooleanPluginKey) => void;
  setPluginVersion: (version: string) => void;
  setPluginAuthor: (author: string) => void;
  setPluginKeywords: (keywords: string) => void;
  setFormData: (data: ExtensionFormData) => void;
  reset: () => void;
}

export const useWizardStore = create<WizardState>()((set) => ({
  currentStep: 1,
  formData: { ...initialFormData },

  setStep: (step) => set({ currentStep: step }),

  nextStep: () =>
    set((state) => ({
      currentStep: Math.min(state.currentStep + 1, 4) as WizardStep,
    })),

  prevStep: () =>
    set((state) => ({
      currentStep: Math.max(state.currentStep - 1, 1) as WizardStep,
    })),

  setExtensionType: (type) =>
    set((state) => ({
      formData: { ...state.formData, extensionType: type },
    })),

  setTemplateId: (id) =>
    set((state) => ({
      formData: { ...state.formData, templateId: id },
    })),

  setName: (name) =>
    set((state) => ({
      formData: { ...state.formData, name },
    })),

  setDescription: (description) =>
    set((state) => ({
      formData: { ...state.formData, description },
    })),

  setOutputLanguage: (lang) =>
    set((state) => ({
      formData: { ...state.formData, outputLanguage: lang },
    })),

  setSkillArgumentHint: (hint) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, argumentHint: hint },
      },
    })),

  setSkillAllowedTools: (tools) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, allowedTools: tools },
      },
    })),

  setSkillModel: (model) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, model },
      },
    })),

  setSkillUserInvocable: (v) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, userInvocable: v },
      },
    })),

  setSkillEffort: (effort) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, effort },
      },
    })),

  setSkillContext: (context) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, context },
      },
    })),

  setSkillAgent: (agent) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, agent },
      },
    })),

  setSkillDisableModelInvocation: (v) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, disableModelInvocation: v },
      },
    })),

  setSkillPaths: (paths) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, paths },
      },
    })),

  setSkillShell: (shell) =>
    set((state) => ({
      formData: {
        ...state.formData,
        skillConfig: { ...state.formData.skillConfig, shell },
      },
    })),

  setAgentTools: (tools) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, tools },
      },
    })),

  setAgentModel: (model) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, model },
      },
    })),

  setAgentMaxTurns: (turns) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, maxTurns: turns },
      },
    })),

  setAgentResearchField: (field) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, researchField: field },
      },
    })),

  setAgentEffort: (effort) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, effort },
      },
    })),

  setAgentDisallowedTools: (tools) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, disallowedTools: tools },
      },
    })),

  setAgentSkills: (skills) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, skills },
      },
    })),

  setAgentIsolation: (isolation) =>
    set((state) => ({
      formData: {
        ...state.formData,
        agentConfig: { ...state.formData.agentConfig, isolation },
      },
    })),

  togglePluginComponent: (key) =>
    set((state) => ({
      formData: {
        ...state.formData,
        pluginConfig: {
          ...state.formData.pluginConfig,
          [key]: !state.formData.pluginConfig[key],
        },
      },
    })),

  setPluginVersion: (version) =>
    set((state) => ({
      formData: {
        ...state.formData,
        pluginConfig: { ...state.formData.pluginConfig, pluginVersion: version },
      },
    })),

  setPluginAuthor: (author) =>
    set((state) => ({
      formData: {
        ...state.formData,
        pluginConfig: { ...state.formData.pluginConfig, pluginAuthor: author },
      },
    })),

  setPluginKeywords: (keywords) =>
    set((state) => ({
      formData: {
        ...state.formData,
        pluginConfig: { ...state.formData.pluginConfig, pluginKeywords: keywords },
      },
    })),

  setFormData: (data) => set({ formData: { ...data } }),

  reset: () => set({ currentStep: 1, formData: { ...initialFormData } }),
}));
