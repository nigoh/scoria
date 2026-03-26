import { ArrowLeft, ArrowRight, Lightning } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { WizardProgress } from "./WizardProgress";
import { Step1ExtensionType } from "./steps/Step1ExtensionType";
import { Step2Template } from "./steps/Step2Template";
import { Step3Config } from "./steps/Step3Config";
import { Step4Content } from "./steps/Step4Content";
import { useWizardStore } from "@/stores/wizardStore";
import { useExtensionStore } from "@/stores/extensionStore";
import { generateExtension, regenerateFiles } from "@/lib/generator";

export function WizardPanel() {
  const { currentStep, formData, nextStep, prevStep } = useWizardStore();
  const { setGeneratedExtension, generatedExtension, updateFiles } = useExtensionStore();

  const handleGenerate = () => {
    const result = generateExtension(formData);
    setGeneratedExtension(result);
  };

  const handleRegenerate = () => {
    if (generatedExtension) {
      const files = regenerateFiles(formData, generatedExtension.blocks);
      updateFiles(files);
    }
  };

  const handleNext = () => {
    if (currentStep === 3) {
      handleGenerate();
      nextStep();
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
        return formData.templateId !== null && formData.name.trim() !== "";
      case 3:
        return true;
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

  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-border px-4 py-3">
        <WizardProgress currentStep={currentStep} />
      </div>
      <div className="flex-1 overflow-y-auto p-4">{stepComponent}</div>
      <div className="flex items-center justify-between border-t border-border px-4 py-3">
        <Button
          variant="ghost"
          onClick={prevStep}
          disabled={currentStep === 1}
          className="gap-1"
        >
          <ArrowLeft size={16} />
          戻る
        </Button>
        <Button onClick={handleNext} disabled={!canProceed} className="gap-1">
          {currentStep === 3 ? (
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
