import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { CopyButton } from "./CopyButton";
import { ImproveSuggestionButton } from "./ImproveSuggestionButton";
import { PromptBlockList } from "./PromptBlockList";
import { usePromptStore } from "@/stores/promptStore";

export function PreviewPanel() {
  const { generatedPrompt, improvementResult } = usePromptStore();

  return (
    <div className="flex h-full flex-col">
      <Tabs defaultValue="preview" className="flex flex-1 flex-col">
        <div className="border-b border-border px-4">
          <TabsList>
            <TabsTrigger value="preview">プレビュー</TabsTrigger>
            <TabsTrigger value="blocks">ブロック編集</TabsTrigger>
            {improvementResult && (
              <TabsTrigger value="improve">改善提案</TabsTrigger>
            )}
          </TabsList>
        </div>
        <TabsContent value="preview" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedPrompt ? (
                <pre className="whitespace-pre-wrap font-mono text-sm leading-relaxed text-foreground">
                  {generatedPrompt.fullText}
                </pre>
              ) : (
                <div className="flex h-64 items-center justify-center text-muted-foreground">
                  <p className="text-center text-sm">
                    左のウィザードを完了すると
                    <br />
                    プロンプトがここに表示されます
                  </p>
                </div>
              )}
            </div>
          </ScrollArea>
        </TabsContent>
        <TabsContent value="blocks" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              <PromptBlockList />
            </div>
          </ScrollArea>
        </TabsContent>
        {improvementResult && (
          <TabsContent value="improve" className="flex-1">
            <ScrollArea className="h-full">
              <div className="p-4">
                <pre className="whitespace-pre-wrap font-mono text-sm leading-relaxed text-foreground">
                  {improvementResult}
                </pre>
              </div>
            </ScrollArea>
          </TabsContent>
        )}
      </Tabs>
      <div className="flex items-center gap-2 border-t border-border px-4 py-3">
        <CopyButton text={generatedPrompt?.fullText ?? ""} />
        <ImproveSuggestionButton />
      </div>
    </div>
  );
}
