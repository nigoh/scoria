/**
 * structured outputs 用の応答スキーマ（ADR-0027）。
 *
 * 注意: structured outputs は minLength / pattern 等の文字列制約を受け付けないため、
 * 形だけをここで強制し、中身の検証（空・kebab-case）は parse.ts が行う。
 */
export const AI_OUTPUT_SCHEMA = {
  type: "object",
  properties: {
    name: {
      type: "string",
      description: "拡張の識別子。kebab-case（例: systematic-review）",
    },
    description: {
      type: "string",
      description: "拡張の用途が1文で分かる説明",
    },
    blocks: {
      type: "array",
      description: "拡張本文の節。上から順に実行できる構成で3〜8個",
      items: {
        type: "object",
        properties: {
          label: { type: "string", description: "節の見出し" },
          content: { type: "string", description: "節の本文（Markdown）" },
        },
        required: ["label", "content"],
        additionalProperties: false,
      },
    },
  },
  required: ["name", "description", "blocks"],
  additionalProperties: false,
} as const;
