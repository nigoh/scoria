import { useState } from "react";
import { ClockCounterClockwise, Trash, ArrowSquareIn } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useHistoryStore } from "@/stores/historyStore";
import { useWizardStore } from "@/stores/wizardStore";
import { useExtensionStore } from "@/stores/extensionStore";
import { regenerateFiles } from "@/lib/generator";
import type { HistoryEntry } from "@/types";

const TYPE_LABELS: Record<string, string> = {
  skill: "スキル",
  agent: "エージェント",
  plugin: "プラグイン",
};

export function HistoryDialog() {
  const [open, setOpen] = useState(false);
  const { entries, deleteEntry, clearAll } = useHistoryStore();
  const { setFormData, setStep } = useWizardStore();
  const { setGeneratedExtension } = useExtensionStore();

  const handleLoad = (entry: HistoryEntry) => {
    setFormData(entry.formData);
    setStep(4);

    const files = regenerateFiles(entry.formData, entry.blocks);
    setGeneratedExtension({
      files,
      blocks: entry.blocks,
      generatedAt: entry.generatedAt,
    });

    setOpen(false);
  };

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString("ja-JP", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <>
      <Button
        variant="ghost"
        size="sm"
        className="gap-1.5"
        onClick={() => setOpen(true)}
      >
        <ClockCounterClockwise size={16} />
        履歴
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>保存した拡張</DialogTitle>
            <DialogDescription>
              過去に保存した拡張を読み込んで再編集できます
            </DialogDescription>
          </DialogHeader>

          {entries.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted-foreground">
              保存された拡張はありません
            </p>
          ) : (
            <>
              <ScrollArea className="max-h-80">
                <div className="space-y-2">
                  {entries.map((entry) => (
                    <div
                      key={entry.id}
                      className="flex items-center gap-3 rounded-lg border border-border p-3"
                    >
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <span className="truncate text-sm font-medium">
                            {entry.name}
                          </span>
                          <Badge variant="outline" className="shrink-0 text-[10px]">
                            {TYPE_LABELS[entry.extensionType] ?? entry.extensionType}
                          </Badge>
                        </div>
                        <div className="mt-0.5 text-xs text-muted-foreground">
                          {formatDate(entry.savedAt)}
                          {entry.formData.outputLanguage === "en" && " · EN"}
                        </div>
                      </div>
                      <div className="flex shrink-0 gap-1">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleLoad(entry)}
                          title="読み込む"
                        >
                          <ArrowSquareIn size={16} />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => deleteEntry(entry.id)}
                          className="text-muted-foreground hover:text-destructive"
                          title="削除"
                        >
                          <Trash size={16} />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </ScrollArea>
              <div className="flex justify-end">
                <Button variant="ghost" size="sm" onClick={clearAll}>
                  すべて削除
                </Button>
              </div>
            </>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
