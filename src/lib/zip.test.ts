import { describe, it, expect } from "vitest";
import JSZip from "jszip";
import { buildZipArchive } from "./zip";
import type { GeneratedFile } from "@/types";

function file(path: string, content: string): GeneratedFile {
  return { path, content, language: "markdown" };
}

/** 生成した ZIP を読み戻して「パス → 中身」に展開する（往復で中身が保たれるかを見る）。 */
async function unzip(bytes: Uint8Array): Promise<Record<string, string>> {
  const zip = await JSZip.loadAsync(bytes);
  const out: Record<string, string> = {};
  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir) continue;
    out[path] = await entry.async("string");
  }
  return out;
}

describe("buildZipArchive", () => {
  it("入れたファイルをパスごと取り出せる", async () => {
    const entries = await unzip(
      await buildZipArchive([
        file(".claude/skills/foo/SKILL.md", "---\nname: foo\n---\n\n本文\n"),
        file("README.md", "# foo\n"),
      ]),
    );

    expect(Object.keys(entries).sort()).toEqual([".claude/skills/foo/SKILL.md", "README.md"]);
    expect(entries["README.md"]).toBe("# foo\n");
    expect(entries[".claude/skills/foo/SKILL.md"]).toContain("name: foo");
  });

  it("日本語の内容が往復で壊れない", async () => {
    const content = "系統的レビューの手順\n① 検索式を作る\n② 重複を除く\n";
    const entries = await unzip(await buildZipArchive([file("a.md", content)]));

    expect(entries["a.md"]).toBe(content);
  });

  it("ファイルが無ければ空のアーカイブになる", async () => {
    const entries = await unzip(await buildZipArchive([]));

    expect(Object.keys(entries)).toEqual([]);
  });

  it("空の内容のファイルもエントリとして残る", async () => {
    const entries = await unzip(await buildZipArchive([file("empty.md", "")]));

    expect(entries).toHaveProperty("empty.md");
    expect(entries["empty.md"]).toBe("");
  });

  it("深い階層のパスをそのまま保持する", async () => {
    const path = ".claude/skills/very/deep/nested/SKILL.md";
    const entries = await unzip(await buildZipArchive([file(path, "本文\n")]));

    expect(Object.keys(entries)).toContain(path);
  });

  it("同じ入力なら中身は毎回同じ（バイト列は時刻を含むので中身で比較する）", async () => {
    // JSZip はエントリに現在時刻を書き込むため、生バイト列の一致は秒の境界をまたぐと崩れる。
    // 実行時刻に依存しない「エントリ集合と内容が同じ」を固定する。
    const files = [file("a.md", "A\n"), file("b.md", "B\n")];
    const [first, second] = await Promise.all([buildZipArchive(files), buildZipArchive(files)]);

    expect(await unzip(second)).toEqual(await unzip(first));
  });
});
