import { SpinnerGap, Sparkle } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { usePromptStore } from "@/stores/promptStore";
import { useSettingsStore } from "@/stores/settingsStore";
import { callLLM } from "@/lib/llm";
import type { LLMMessage } from "@/types";

export function ImproveSuggestionButton() {
  const { generatedPrompt, isImproving, setImproving, setImprovementResult } =
    usePromptStore();
  const { settings } = useSettingsStore();
  const activeConfig = settings.providers[settings.activeProvider];
  const hasApiKey = activeConfig.encryptedApiKey !== null;
  const hasPrompt = generatedPrompt !== null;

  const handleImprove = async () => {
    if (!generatedPrompt) return;
    setImproving(true);
    setImprovementResult(null);

    const messages: LLMMessage[] = [
      {
        role: "system",
        content:
          "あなたは学術文献検索と研究方法論の専門家です。与えられたプロンプトの改善点を分析し、具体的な改善案を提示してください。",
      },
      {
        role: "user",
        content: `以下のプロンプトの改善点を具体的に指摘し、改善されたプロンプトを返してください。\n\n---\n${generatedPrompt.fullText}\n---\n\n評価観点:\n1. 具体性（曖昧な表現の有無）\n2. 構造性（プロンプト構成の最適性）\n3. 再現性（他者が同じ結果を得られるか）\n4. DB適合性（検索DBに最適化されているか）\n\n改善点をリストで示した後、改善後のプロンプト全文を出力してください。`,
      },
    ];

    try {
      const result = await callLLM(messages, activeConfig);
      setImprovementResult(result);
    } catch (err) {
      setImprovementResult(
        `エラー: ${err instanceof Error ? err.message : "不明なエラー"}`,
      );
    } finally {
      setImproving(false);
    }
  };

  const button = (
    <Button
      variant="outline"
      size="sm"
      onClick={handleImprove}
      disabled={!hasApiKey || !hasPrompt || isImproving}
      className="gap-1.5"
    >
      {isImproving ? (
        <SpinnerGap size={16} className="animate-spin" />
      ) : (
        <Sparkle size={16} />
      )}
      {isImproving ? "改善中..." : "AIで改善"}
    </Button>
  );

  if (!hasApiKey) {
    return (
      <Tooltip>
        <TooltipTrigger asChild>{button}</TooltipTrigger>
        <TooltipContent>設定画面でAPIキーを登録してください</TooltipContent>
      </Tooltip>
    );
  }

  return button;
}
