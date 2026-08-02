import { PromptBlockList } from "../PromptBlockList";
import { useExtensionStore } from "@/stores/extensionStore";
import { StepHeading } from "../StepHeading";

export function Step4Content() {
  const { generatedExtension } = useExtensionStore();

  return (
    <div className="space-y-4">
      <StepHeading
        title="内容を編集"
        hint="ブロックの本文を書き換え、並べ替え、不要なものを外せます。"
      />
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
