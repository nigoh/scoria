import { useState } from "react";
import { ArrowLeft, ArrowRight, CircleNotch, Lightning, Sparkle } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { WizardProgress } from "./WizardProgress";
import { HistoryDialog } from "./HistoryDialog";
import { SettingsDialog } from "./SettingsDialog";
import { Step1ExtensionType } from "./steps/Step1ExtensionType";
import { Step2Template } from "./steps/Step2Template";
import { Step3Config } from "./steps/Step3Config";
import { Step4Content } from "./steps/Step4Content";
import { useWizardStore } from "@/stores/wizardStore";
import { useExtensionStore } from "@/stores/extensionStore";
import { useSettingsStore } from "@/stores/settingsStore";
import { generateExtension, regenerateFiles } from "@/lib/generator";
import { requestDesign } from "@/lib/ai/client";
import { applyAiDesign } from "@/lib/ai/design";

export function WizardPanel() {
  const { currentStep, formData, nextStep, prevStep, designMode, aiBrief, setFormData } =
    useWizardStore();
  const { setGeneratedExtension, generatedExtension, updateFiles } = useExtensionStore();
  const { apiKey, aiModel } = useSettingsStore();
  const [aiBusy, setAiBusy] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);

  const handleGenerate = () => {
    const result = generateExtension(formData);
    setGeneratedExtension(result);
  };

  /**
   * AI 設計（ADR-0027）: 応答は検証（parse）を通り、ファイルは決定論ジェネレータが
   * 組み立てる。失敗は aiError に写像してこの画面で伝える。
   */
  const handleAiGenerate = async () => {
    if (formData.extensionType === null) return;
    setAiBusy(true);
    setAiError(null);
    const result = await requestDesign({
      apiKey,
      model: aiModel,
      extensionType: formData.extensionType,
      outputLanguage: formData.outputLanguage,
      brief: aiBrief,
      nameHint: formData.name,
      descriptionHint: formData.description,
    });
    setAiBusy(false);

    if (!result.ok) {
      setAiError(result.error);
      return;
    }
    const applied = applyAiDesign(formData, result.value);
    setFormData(applied.formData);
    setGeneratedExtension(applied.extension);
    nextStep();
  };

  const handleRegenerate = () => {
    if (generatedExtension) {
      const files = regenerateFiles(formData, generatedExtension.blocks);
      updateFiles(files);
    }
  };

  const handleNext = () => {
    if (currentStep === 3) {
      if (designMode === "ai") {
        void handleAiGenerate();
      } else {
        handleGenerate();
        nextStep();
      }
    } else if (currentStep === 4) {
      handleRegenerate();
    } else {
      nextStep();
    }
  };

  const canProceed = (() => {
    switch (currentStep) {
      case 1:
        return formData.extensionType !== null;
      case 2:
        return designMode === "ai"
          ? aiBrief.trim() !== ""
          : formData.templateId !== null && formData.name.trim() !== "";
      case 3:
        return !aiBusy;
      case 4:
        return generatedExtension !== null;
      default:
        return false;
    }
  })();

  const stepComponent = {
    1: <Step1ExtensionType />,
    2: <Step2Template />,
    3: <Step3Config />,
    4: <Step4Content />,
  }[currentStep];

  const isAiGenerateStep = currentStep === 3 && designMode === "ai";

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-3 border-b border-border bg-card px-3 py-2">
        <WizardProgress currentStep={currentStep} />
        <SettingsDialog />
        <HistoryDialog />
      </div>
      <div className="flex-1 overflow-y-auto p-4">{stepComponent}</div>
      {aiError && currentStep === 3 && (
        <div
          role="alert"
          className="border-t border-destructive/40 bg-destructive/10 px-4 py-2 font-sans text-xs text-destructive"
        >
          {aiError}
        </div>
      )}
      <div className="flex items-center justify-between border-t border-border bg-card px-3 py-2">
        <Button
          variant="ghost"
          onClick={prevStep}
          disabled={currentStep === 1 || aiBusy}
          className="gap-1"
        >
          <ArrowLeft size={16} />
          戻る
        </Button>
        <Button onClick={handleNext} disabled={!canProceed} className="gap-1">
          {isAiGenerateStep ? (
            aiBusy ? (
              <>
                <CircleNotch size={16} className="animate-spin" />
                AI 設計中…
              </>
            ) : (
              <>
                <Sparkle size={16} />
                AI で生成
              </>
            )
          ) : currentStep === 3 ? (
            <>
              <Lightning size={16} />
              生成
            </>
          ) : currentStep === 4 ? (
            <>
              <Lightning size={16} />
              再生成
            </>
          ) : (
            <>
              次へ
              <ArrowRight size={16} />
            </>
          )}
        </Button>
      </div>
    </div>
  );
}
