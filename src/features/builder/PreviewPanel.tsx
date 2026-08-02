import { useState } from "react";
import { FloppyDisk, Check } from "@phosphor-icons/react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { CopyButton } from "./CopyButton";
import { DownloadButton } from "./DownloadButton";
import { CliDialog } from "./CliDialog";
import { FileTreeView } from "./FileTreeView";
import { FilePreview } from "./FilePreview";
import { PromptBlockList } from "./PromptBlockList";
import { useExtensionStore } from "@/stores/extensionStore";
import { useWizardStore } from "@/stores/wizardStore";
import { useHistoryStore } from "@/stores/historyStore";

type PreviewTab = "files" | "preview" | "blocks";

export function PreviewPanel() {
  const { generatedExtension, selectedFilePath } = useExtensionStore();
  const { formData } = useWizardStore();
  const { saveEntry } = useHistoryStore();
  const [activeTab, setActiveTab] = useState<PreviewTab>("files");
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    if (!generatedExtension) return;
    saveEntry(formData, generatedExtension.blocks, generatedExtension.generatedAt);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const copyText = (() => {
    if (!generatedExtension) return "";
    const file = generatedExtension.files.find((f) => f.path === selectedFilePath);
    return file?.content ?? "";
  })();

  return (
    <div className="flex h-full flex-col">
      <Tabs
        value={activeTab}
        onValueChange={(v) => setActiveTab(v as PreviewTab)}
        className="flex flex-1 flex-col"
      >
        <div className="border-b border-border bg-card px-3">
          <TabsList>
            <TabsTrigger value="files">ファイルツリー</TabsTrigger>
            <TabsTrigger value="preview">プレビュー</TabsTrigger>
            <TabsTrigger value="blocks">ブロック編集</TabsTrigger>
          </TabsList>
        </div>

        <TabsContent value="files" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedExtension ? <FileTreeView /> : <EmptyPlaceholder />}
            </div>
          </ScrollArea>
        </TabsContent>

        <TabsContent value="preview" className="flex-1">
          {generatedExtension ? (
            <FilePreview />
          ) : (
            <div className="p-4">
              <EmptyPlaceholder />
            </div>
          )}
        </TabsContent>

        <TabsContent value="blocks" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedExtension ? <PromptBlockList /> : <EmptyPlaceholder />}
            </div>
          </ScrollArea>
        </TabsContent>
      </Tabs>

      <div className="flex items-center gap-2 border-t border-border bg-card px-3 py-2">
        <CopyButton text={copyText} />
        <CliDialog />
        <Button
          variant="outline"
          size="sm"
          className="gap-1.5"
          disabled={!generatedExtension}
          onClick={handleSave}
        >
          {saved ? <Check size={14} /> : <FloppyDisk size={14} />}
          {saved ? "保存済み" : "保存"}
        </Button>
        <DownloadButton />
      </div>
    </div>
  );
}

/**
 * 生成前の状態（ADR-0026）。
 * 中央にイラストを置くのはやめ、これから何が起きるかを左揃えの手順として示す。
 * 空の広い面より、次に押す場所が分かることを優先する。
 */
function EmptyPlaceholder() {
  const steps = [
    "拡張タイプを選ぶ",
    "テンプレートと名前を決める",
    "詳細を設定する",
    "生成して内容を整える",
  ];

  return (
    <div className="max-w-md space-y-3 text-sm">
      <p className="text-muted-foreground">
        <span className="text-primary">$</span> まだ生成していません
        <span className="animate-caret ml-0.5 text-primary">▌</span>
      </p>
      <ol className="space-y-1 text-xs text-muted-foreground">
        {steps.map((label, i) => (
          <li key={label} className="flex gap-2">
            <span className="tabular-nums text-signal">[{i + 1}/4]</span>
            <span className="font-sans">{label}</span>
          </li>
        ))}
      </ol>
      <p className="font-sans text-xs leading-relaxed text-muted-foreground">
        4つ目まで進むと、生成されたファイルがここに並びます。
      </p>
    </div>
  );
}
