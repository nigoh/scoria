import { useState } from "react";
import { FloppyDisk, Check } from "@phosphor-icons/react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { EmptyStateIllustration } from "@/components/illustrations/EmptyStateIllustration";
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
        <div className="border-b border-border px-4">
          <TabsList>
            <TabsTrigger value="files">ファイルツリー</TabsTrigger>
            <TabsTrigger value="preview">プレビュー</TabsTrigger>
            <TabsTrigger value="blocks">ブロック編集</TabsTrigger>
          </TabsList>
        </div>

        <TabsContent value="files" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedExtension ? (
                <FileTreeView />
              ) : (
                <EmptyPlaceholder />
              )}
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
              {generatedExtension ? (
                <PromptBlockList />
              ) : (
                <EmptyPlaceholder />
              )}
            </div>
          </ScrollArea>
        </TabsContent>
      </Tabs>

      <div className="flex items-center gap-2 border-t border-border px-4 py-3">
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

function EmptyPlaceholder() {
  return (
    <div className="flex h-80 flex-col items-center justify-center gap-4 text-muted-foreground">
      <EmptyStateIllustration className="h-48 w-auto" />
      <p className="text-center text-sm">
        ウィザードを完了すると
        <br />
        生成ファイルがここに表示されます
      </p>
    </div>
  );
}
