import { describe, it, expect, beforeEach } from "vitest";
import { installMemoryStorage } from "./testStorage";

installMemoryStorage();

const { useExtensionStore } = await import("./extensionStore");
import type { GeneratedExtension } from "@/types";

const store = () => useExtensionStore.getState();

function extension(): GeneratedExtension {
  return {
    files: [
      { path: ".claude/skills/x/SKILL.md", content: "本文\n", language: "markdown" },
      { path: "README.md", content: "# x\n", language: "markdown" },
    ],
    blocks: [
      { id: "b1", label: "手順", content: "1. やる", enabled: true },
      { id: "b2", label: "注意", content: "気をつける", enabled: true },
      { id: "b3", label: "参考", content: "文献", enabled: true },
    ],
    generatedAt: "2026-08-02T00:00:00.000Z",
  };
}

const blockIds = () => store().generatedExtension!.blocks.map((b) => b.id);

beforeEach(() => {
  store().reset();
});

describe("setGeneratedExtension", () => {
  it("最初のファイルを選択状態にする", () => {
    store().setGeneratedExtension(extension());

    expect(store().selectedFilePath).toBe(".claude/skills/x/SKILL.md");
  });

  it("ファイルが1つも無ければ選択状態を持たない", () => {
    store().setGeneratedExtension({ ...extension(), files: [] });

    expect(store().selectedFilePath).toBeNull();
  });
});

describe("生成物が無いときの操作", () => {
  // 生成前に UI から操作が飛んでも落ちないこと（早期 return の契約）
  it.each([
    ["toggleBlock", () => store().toggleBlock("b1")],
    ["updateBlockContent", () => store().updateBlockContent("b1", "x")],
    ["addBlock", () => store().addBlock("新", "内容")],
    ["removeBlock", () => store().removeBlock("b1")],
    ["reorderBlocks", () => store().reorderBlocks("b1", "b2")],
    ["updateFiles", () => store().updateFiles([])],
  ])("%s は何もせず生成物を null のまま保つ", (_name, act) => {
    expect(act).not.toThrow();
    expect(store().generatedExtension).toBeNull();
  });
});

describe("ブロックの編集", () => {
  beforeEach(() => {
    store().setGeneratedExtension(extension());
  });

  it("toggleBlock で有効・無効を切り替える", () => {
    store().toggleBlock("b2");
    expect(store().generatedExtension!.blocks.find((b) => b.id === "b2")!.enabled).toBe(false);

    store().toggleBlock("b2");
    expect(store().generatedExtension!.blocks.find((b) => b.id === "b2")!.enabled).toBe(true);
  });

  it("toggleBlock は対象以外を変えない", () => {
    store().toggleBlock("b2");
    expect(store().generatedExtension!.blocks.find((b) => b.id === "b1")!.enabled).toBe(true);
    expect(store().generatedExtension!.blocks.find((b) => b.id === "b3")!.enabled).toBe(true);
  });

  it("updateBlockContent は本文だけを差し替える", () => {
    store().updateBlockContent("b1", "書き換えた");
    const b1 = store().generatedExtension!.blocks.find((b) => b.id === "b1")!;

    expect(b1.content).toBe("書き換えた");
    expect(b1.label).toBe("手順");
    expect(b1.enabled).toBe(true);
  });

  it("addBlock は末尾に有効なブロックを足す", () => {
    store().addBlock("追加", "内容");
    const blocks = store().generatedExtension!.blocks;

    expect(blocks).toHaveLength(4);
    expect(blocks[3].label).toBe("追加");
    expect(blocks[3].enabled).toBe(true);
    expect(blocks[3].id).not.toBe("");
  });

  it("addBlock が生成する id は既存と衝突しない", () => {
    store().addBlock("a", "1");
    store().addBlock("b", "2");
    const ids = blockIds();

    expect(new Set(ids).size).toBe(ids.length);
  });

  it("removeBlock は該当ブロックだけを消す", () => {
    store().removeBlock("b2");
    expect(blockIds()).toEqual(["b1", "b3"]);
  });

  it("存在しない id の操作は何も変えない", () => {
    const before = store().generatedExtension!.blocks;
    store().removeBlock("nope");
    store().toggleBlock("nope");
    store().updateBlockContent("nope", "x");

    expect(store().generatedExtension!.blocks).toEqual(before);
  });
});

describe("reorderBlocks", () => {
  beforeEach(() => {
    store().setGeneratedExtension(extension());
  });

  it("前から後ろへ移動する", () => {
    store().reorderBlocks("b1", "b3");
    expect(blockIds()).toEqual(["b2", "b3", "b1"]);
  });

  it("後ろから前へ移動する", () => {
    store().reorderBlocks("b3", "b1");
    expect(blockIds()).toEqual(["b3", "b1", "b2"]);
  });

  it("同じ位置への移動は並びを変えない", () => {
    store().reorderBlocks("b2", "b2");
    expect(blockIds()).toEqual(["b1", "b2", "b3"]);
  });

  it("存在しない id を渡しても並びを壊さない", () => {
    store().reorderBlocks("b1", "nope");
    expect(blockIds()).toEqual(["b1", "b2", "b3"]);

    store().reorderBlocks("nope", "b1");
    expect(blockIds()).toEqual(["b1", "b2", "b3"]);
  });
});

describe("updateFiles", () => {
  it("ファイルだけを差し替え、ブロックは保つ", () => {
    store().setGeneratedExtension(extension());
    store().updateFiles([{ path: "a.md", content: "A\n", language: "markdown" }]);

    expect(store().generatedExtension!.files).toHaveLength(1);
    expect(store().generatedExtension!.blocks).toHaveLength(3);
  });
});

describe("reset", () => {
  it("生成物と選択状態を消す", () => {
    store().setGeneratedExtension(extension());
    store().reset();

    expect(store().generatedExtension).toBeNull();
    expect(store().selectedFilePath).toBeNull();
  });
});
