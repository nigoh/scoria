import { ArrowLeft, ArrowRight } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { WizardProgress } from "./WizardProgress";
import { Step1ResearchPhase } from "./steps/Step1ResearchPhase";
import { Step2Field } from "./steps/Step2Field";
import { Step3Keywords } from "./steps/Step3Keywords";
import { Step4Purpose } from "./steps/Step4Purpose";
import { Step5Conditions } from "./steps/Step5Conditions";
import { useWizardStore } from "@/stores/wizardStore";
import { usePromptStore } from "@/stores/promptStore";
import { generateBlockedPrompt } from "@/lib/prompt";

export function WizardPanel() {
  const { currentStep, formData, nextStep, prevStep } = useWizardStore();
  const { setGeneratedPrompt } = usePromptStore();

  const handleGenerate = () => {
    const result = generateBlockedPrompt(formData);
    setGeneratedPrompt(result);
  };

  const handleNext = () => {
    if (currentStep === 5) {
      handleGenerate();
    } else {
      nextStep();
    }
  };

  const stepComponent = {
    1: <Step1ResearchPhase />,
    2: <Step2Field />,
    3: <Step3Keywords />,
    4: <Step4Purpose />,
    5: <Step5Conditions />,
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
        <Button onClick={handleNext} className="gap-1">
          {currentStep === 5 ? "プロンプト生成" : "次へ"}
          {currentStep < 5 && <ArrowRight size={16} />}
        </Button>
      </div>
    </div>
  );
}
