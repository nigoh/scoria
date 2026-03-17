import { useState } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Badge } from "@/components/ui/badge";
import { EmptyStateIllustration } from "@/components/illustrations/EmptyStateIllustration";
import { CopyButton } from "./CopyButton";
import { ImproveSuggestionButton } from "./ImproveSuggestionButton";
import { PromptBlockList } from "./PromptBlockList";
import { usePromptStore } from "@/stores/promptStore";

type PreviewTab = "full" | "system" | "user" | "blocks" | "improve";

export function PreviewPanel() {
  const { generatedPrompt, improvementResult } = usePromptStore();
  const [activeTab, setActiveTab] = useState<PreviewTab>("full");

  const copyText = (() => {
    if (!generatedPrompt) return "";
    switch (activeTab) {
      case "system":
        return generatedPrompt.systemPrompt;
      case "user":
        return generatedPrompt.userPrompt;
      default:
        return generatedPrompt.fullText;
    }
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
            <TabsTrigger value="full">統合版</TabsTrigger>
            <TabsTrigger value="system">
              System
              <Badge variant="outline" className="ml-1 text-[9px]">
                API
              </Badge>
            </TabsTrigger>
            <TabsTrigger value="user">User</TabsTrigger>
            <TabsTrigger value="blocks">ブロック</TabsTrigger>
            {improvementResult && (
              <TabsTrigger value="improve">改善提案</TabsTrigger>
            )}
          </TabsList>
        </div>

        {/* 統合版 */}
        <TabsContent value="full" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedPrompt ? (
                <pre className="whitespace-pre-wrap font-mono text-sm leading-relaxed text-foreground">
                  {generatedPrompt.fullText}
                </pre>
              ) : (
                <EmptyPlaceholder />
              )}
            </div>
          </ScrollArea>
        </TabsContent>

        {/* System Prompt */}
        <TabsContent value="system" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedPrompt ? (
                <>
                  <div className="mb-3 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
                    Claude API の <code className="rounded bg-amber-100 px-1 dark:bg-amber-900">system</code> パラメータに設定して使います
                  </div>
                  <pre className="whitespace-pre-wrap font-mono text-sm leading-relaxed text-foreground">
                    {generatedPrompt.systemPrompt}
                  </pre>
                </>
              ) : (
                <EmptyPlaceholder />
              )}
            </div>
          </ScrollArea>
        </TabsContent>

        {/* User Prompt */}
        <TabsContent value="user" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              {generatedPrompt ? (
                <>
                  <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-xs text-blue-800 dark:border-blue-900 dark:bg-blue-950 dark:text-blue-200">
                    チャットに直接コピペして使うプロンプトです
                  </div>
                  <pre className="whitespace-pre-wrap font-mono text-sm leading-relaxed text-foreground">
                    {generatedPrompt.userPrompt}
                  </pre>
                </>
              ) : (
                <EmptyPlaceholder />
              )}
            </div>
          </ScrollArea>
        </TabsContent>

        {/* ブロック編集 */}
        <TabsContent value="blocks" className="flex-1">
          <ScrollArea className="h-full">
            <div className="p-4">
              <PromptBlockList />
            </div>
          </ScrollArea>
        </TabsContent>

        {/* 改善提案 */}
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
        <CopyButton text={copyText} />
        <ImproveSuggestionButton />
      </div>
    </div>
  );
}

function EmptyPlaceholder() {
  return (
    <div className="flex h-80 flex-col items-center justify-center gap-4 text-muted-foreground">
      <EmptyStateIllustration className="h-48 w-auto" />
      <p className="text-center text-sm">
        左のウィザードを完了すると
        <br />
        プロンプトがここに表示されます
      </p>
    </div>
  );
}
