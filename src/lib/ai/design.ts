import { nanoid } from "nanoid";
import type { AiDesignResult, ContentBlock, ExtensionFormData, GeneratedExtension } from "@/types";
import { regenerateFiles } from "@/lib/generator";

/**
 * 検証済みの AI 設計結果を、既存の決定論ジェネレータで拡張に組み立てる
 * （ADR-0027 / REQ-AI-003）。
 *
 * AI が決めるのは name / description / blocks だけで、frontmatter・パス・ファイル構成は
 * テスト済みの regenerateFiles が組み立てる。だから AI 経由でも仕様違反のファイルが出ない。
 * templateId は "custom"（自由記述の受け皿）として既存のフローに乗せる。
 */
export function applyAiDesign(
  formData: ExtensionFormData,
  design: AiDesignResult,
): { formData: ExtensionFormData; extension: GeneratedExtension } {
  const patched: ExtensionFormData = {
    ...formData,
    templateId: "custom",
    name: design.name,
    description: design.description,
  };

  const blocks: ContentBlock[] = design.blocks.map((b) => ({
    id: nanoid(),
    label: b.label,
    content: b.content,
    enabled: true,
  }));

  return {
    formData: patched,
    extension: {
      files: regenerateFiles(patched, blocks),
      blocks,
      generatedAt: new Date().toISOString(),
    },
  };
}
