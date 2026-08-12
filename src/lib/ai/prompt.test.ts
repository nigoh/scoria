import { describe, it, expect } from "vitest";
import { buildSystemPrompt, buildUserPrompt } from "./prompt";

// Verifies: REQ-AI-001

describe("buildSystemPrompt", () => {
  it("拡張タイプごとに出力先と役割が変わる", () => {
    const skill = buildSystemPrompt("skill", "ja");
    const agent = buildSystemPrompt("agent", "ja");

    expect(skill).toContain("SKILL.md");
    expect(agent).toContain(".claude/agents/");
    expect(skill).not.toBe(agent);
  });

  it("学術研究の文脈が含まれる", () => {
    expect(buildSystemPrompt("skill", "ja")).toContain("学術研究");
  });

  it("出力言語 en では本文を英語で書く指示が入る", () => {
    const en = buildSystemPrompt("skill", "en");
    expect(en).toMatch(/English/);
  });

  it("応答形式（name / description / blocks）の契約を明示する", () => {
    const p = buildSystemPrompt("plugin", "ja");
    expect(p).toContain("name");
    expect(p).toContain("description");
    expect(p).toContain("blocks");
    expect(p).toContain("kebab-case");
  });
});

describe("buildUserPrompt", () => {
  it("自由記述がユーザープロンプトに含まれ、システム側には混ざらない", () => {
    const brief = "系統的レビューの検索式を PICO で組み立てたい";
    const user = buildUserPrompt({ brief, name: "", description: "" });
    const system = buildSystemPrompt("skill", "ja");

    expect(user).toContain(brief);
    expect(system).not.toContain(brief);
  });

  it("名前・説明のヒントがあれば含める", () => {
    const user = buildUserPrompt({
      brief: "引用チェック",
      name: "cite-check",
      description: "引用整合性の検証",
    });

    expect(user).toContain("cite-check");
    expect(user).toContain("引用整合性の検証");
  });

  it("ヒントが空ならヒント行を出さない", () => {
    const user = buildUserPrompt({ brief: "引用チェック", name: "", description: "" });
    expect(user).not.toContain("希望する名前");
  });
});
