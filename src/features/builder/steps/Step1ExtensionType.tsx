import { Command, Robot, Package } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import { useWizardStore } from "@/stores/wizardStore";
import { EXTENSION_TYPES } from "@/lib/constants";
import type { ExtensionType } from "@/types";

const ICONS: Record<string, React.ElementType> = {
  Command,
  Robot,
  Package,
};

export function Step1ExtensionType() {
  const { formData, setExtensionType } = useWizardStore();

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold">拡張タイプを選択</h2>
        <p className="text-sm text-muted-foreground">
          作成するClaude Code拡張の種類を選んでください
        </p>
      </div>
      <div className="grid gap-3">
        {EXTENSION_TYPES.map((ext) => {
          const Icon = ICONS[ext.icon];
          const isSelected = formData.extensionType === ext.id;
          return (
            <button
              key={ext.id}
              onClick={() => setExtensionType(ext.id as ExtensionType)}
              className={cn(
                "flex items-start gap-3 rounded-lg border p-4 text-left transition-colors",
                isSelected
                  ? "border-primary bg-primary/5"
                  : "border-border hover:border-primary/50",
              )}
            >
              {Icon && (
                <Icon
                  size={24}
                  weight="duotone"
                  className={cn(
                    "mt-0.5 shrink-0",
                    isSelected ? "text-primary" : "text-muted-foreground",
                  )}
                />
              )}
              <div>
                <div className="font-medium">{ext.labelJa}</div>
                <div className="mt-1 text-sm text-muted-foreground">{ext.descriptionJa}</div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
