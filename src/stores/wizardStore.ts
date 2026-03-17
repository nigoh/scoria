import { create } from "zustand";
import { nanoid } from "nanoid";
import type { ResearchPhase, WizardStep, WizardFormData } from "@/types";
import { ALL_DATABASE_IDS } from "@/lib/databases";

const initialFormData: WizardFormData = {
  phase: null,
  field: null,
  keywords: [],
  purpose: "",
  comparisonItems: ["", ""],
  comparisonAxes: [""],
  conditions: {
    enabledDatabaseIds: [...ALL_DATABASE_IDS],
    outputLanguage: "ja",
    yearRange: { from: null, to: null },
  },
};

interface WizardState {
  currentStep: WizardStep;
  formData: WizardFormData;
  setStep: (step: WizardStep) => void;
  nextStep: () => void;
  prevStep: () => void;
  setPhase: (phase: ResearchPhase) => void;
  setField: (field: string) => void;
  addKeyword: (value: string) => void;
  removeKeyword: (id: string) => void;
  setPurpose: (purpose: string) => void;
  setComparisonItems: (items: string[]) => void;
  setComparisonAxes: (axes: string[]) => void;
  setOutputLanguage: (lang: "ja" | "en") => void;
  setYearRange: (from: number | null, to: number | null) => void;
  toggleDatabase: (dbId: string) => void;
  setAllDatabases: (ids: string[]) => void;
  reset: () => void;
}

export const useWizardStore = create<WizardState>()((set) => ({
  currentStep: 1,
  formData: { ...initialFormData },

  setStep: (step) => set({ currentStep: step }),

  nextStep: () =>
    set((state) => ({
      currentStep: Math.min(state.currentStep + 1, 5) as WizardStep,
    })),

  prevStep: () =>
    set((state) => ({
      currentStep: Math.max(state.currentStep - 1, 1) as WizardStep,
    })),

  setPhase: (phase) =>
    set((state) => ({
      formData: { ...state.formData, phase },
    })),

  setField: (field) =>
    set((state) => ({
      formData: { ...state.formData, field },
    })),

  addKeyword: (value) =>
    set((state) => {
      if (state.formData.keywords.length >= 10) return state;
      if (state.formData.keywords.some((k) => k.value === value)) return state;
      return {
        formData: {
          ...state.formData,
          keywords: [...state.formData.keywords, { id: nanoid(), value }],
        },
      };
    }),

  removeKeyword: (id) =>
    set((state) => ({
      formData: {
        ...state.formData,
        keywords: state.formData.keywords.filter((k) => k.id !== id),
      },
    })),

  setPurpose: (purpose) =>
    set((state) => ({
      formData: { ...state.formData, purpose },
    })),

  setComparisonItems: (items) =>
    set((state) => ({
      formData: { ...state.formData, comparisonItems: items },
    })),

  setComparisonAxes: (axes) =>
    set((state) => ({
      formData: { ...state.formData, comparisonAxes: axes },
    })),

  setOutputLanguage: (lang) =>
    set((state) => ({
      formData: {
        ...state.formData,
        conditions: { ...state.formData.conditions, outputLanguage: lang },
      },
    })),

  setYearRange: (from, to) =>
    set((state) => ({
      formData: {
        ...state.formData,
        conditions: {
          ...state.formData.conditions,
          yearRange: { from, to },
        },
      },
    })),

  toggleDatabase: (dbId) =>
    set((state) => {
      const ids = state.formData.conditions.enabledDatabaseIds;
      const next = ids.includes(dbId)
        ? ids.filter((id) => id !== dbId)
        : [...ids, dbId];
      return {
        formData: {
          ...state.formData,
          conditions: { ...state.formData.conditions, enabledDatabaseIds: next },
        },
      };
    }),

  setAllDatabases: (ids) =>
    set((state) => ({
      formData: {
        ...state.formData,
        conditions: { ...state.formData.conditions, enabledDatabaseIds: ids },
      },
    })),

  reset: () => set({ currentStep: 1, formData: { ...initialFormData } }),
}));
