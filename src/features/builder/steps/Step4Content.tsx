import { PromptBlockList } from "../PromptBlockList";
import { useExtensionStore } from "@/stores/extensionStore";

export function Step4Content() {
  const { generatedExtension } = useExtensionStore();

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold">内容を編集</h2>
        <p className="text-sm text-muted-foreground">
          生成されたブロックの内容を編集・並べ替え・トグルできます
        </p>
      </div>
      {generatedExtension ? (
        <PromptBlockList />
      ) : (
        <p className="text-sm text-muted-foreground">
          まだ生成されていません。「生成」ボタンを押してください。
        </p>
      )}
    </div>
  );
}
