import { create } from "zustand";
import type {
  ExtensionType,
  TemplateId,
  WizardStep,
  ExtensionFormData,
  ModelChoice,
} from "@/types";

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
  setAgentTools: (tools: string[]) => void;
  setAgentModel: (model: ModelChoice) => void;
  setAgentMaxTurns: (turns: number) => void;
  setAgentResearchField: (field: string | null) => void;
  togglePluginComponent: (key: keyof ExtensionFormData["pluginConfig"]) => void;
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

  reset: () => set({ currentStep: 1, formData: { ...initialFormData } }),
}));
