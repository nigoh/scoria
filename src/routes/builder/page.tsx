import { WizardPanel } from "@/features/builder/WizardPanel";
import { PreviewPanel } from "@/features/builder/PreviewPanel";

export function Component() {
  return (
    <div className="flex h-[calc(100vh-3.5rem)]">
      <div className="w-full border-r border-border md:w-2/5 lg:w-[38%]">
        <WizardPanel />
      </div>
      <div className="hidden flex-1 md:block">
        <PreviewPanel />
      </div>
    </div>
  );
}
