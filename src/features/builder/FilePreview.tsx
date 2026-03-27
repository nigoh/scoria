import { ScrollArea } from "@/components/ui/scroll-area";
import { useExtensionStore } from "@/stores/extensionStore";

export function FilePreview() {
  const { generatedExtension, selectedFilePath } = useExtensionStore();

  if (!generatedExtension) return null;

  const file = generatedExtension.files.find((f) => f.path === selectedFilePath);

  if (!file) {
    return (
      <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
        ファイルを選択してください
      </div>
    );
  }

  return (
    <ScrollArea className="h-full">
      <div className="p-4">
        <div className="mb-2 text-xs font-medium text-muted-foreground">{file.path}</div>
        <pre className="whitespace-pre-wrap rounded-lg border bg-muted/50 p-3 font-mono text-sm leading-relaxed">
          {file.content}
        </pre>
      </div>
    </ScrollArea>
  );
}
