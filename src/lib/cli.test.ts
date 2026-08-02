import { describe, it, expect } from "vitest";
import { generateCliScript } from "./cli";
import type { GeneratedFile } from "@/types";

function file(path: string, content: string): GeneratedFile {
  return { path, content, language: "markdown" };
}

/**
 * ヒアドキュメントの終端は「行頭に区切り語だけがある行」でなければならない。
 * 生成されたスクリプトがその契約を守っているかを、シェルの規則どおりに検査する。
 */
function heredocTerminatorsAreValid(script: string): boolean {
  const lines = script.split("\n");
  let open: string | null = null;
  for (const line of lines) {
    if (open === null) {
      const m = /<<'([^']+)'/.exec(line);
      if (m) open = m[1];
      continue;
    }
    if (line === open) open = null;
  }
  return open === null;
}

describe("generateCliScript", () => {
  it("ファイルが無ければ空文字を返す", () => {
    expect(generateCliScript([])).toBe("");
  });

  it("直下のファイルは mkdir なしでヒアドキュメントに包む", () => {
    const script = generateCliScript([file("README.md", "# タイトル\n")]);

    expect(script).toContain("cat <<'SCORIA_EOF' > README.md");
    expect(script).not.toContain("mkdir");
    expect(script).toContain("# タイトル");
    expect(heredocTerminatorsAreValid(script)).toBe(true);
  });

  it("サブディレクトリのファイルは mkdir -p を前置する", () => {
    const script = generateCliScript([file(".claude/skills/foo/SKILL.md", "本文\n")]);

    expect(script).toContain("mkdir -p .claude/skills/foo &&");
    expect(script).toContain("cat <<'SCORIA_EOF' > .claude/skills/foo/SKILL.md");
    expect(heredocTerminatorsAreValid(script)).toBe(true);
  });

  it("複数ファイルは空行で区切って並べる", () => {
    const script = generateCliScript([file("a.md", "A\n"), file("b.md", "B\n")]);

    expect(script).toContain("> a.md");
    expect(script).toContain("> b.md");
    expect(script.split("\n\n").length).toBeGreaterThan(1);
    expect(heredocTerminatorsAreValid(script)).toBe(true);
  });

  // --- ここから敵対的ケース（.claude/rules/tdd.md: パーサはエッジが集中する） ---

  it("本文に既定の区切り語が現れたら別の区切り語に切り替える", () => {
    const script = generateCliScript([file("a.md", "説明の中に SCORIA_EOF と書いてある\n")]);

    expect(heredocTerminatorsAreValid(script)).toBe(true);
    const delimiter = /<<'([^']+)'/.exec(script)?.[1];
    expect(delimiter).toBeDefined();
    expect(delimiter).not.toBe("SCORIA_EOF");
  });

  it("候補の区切り語がすべて本文に現れても衝突しない区切り語を選ぶ", () => {
    const content = "SCORIA_EOF も SCORIA_END も両方書いてある\n";
    const script = generateCliScript([file("a.md", content)]);

    expect(heredocTerminatorsAreValid(script)).toBe(true);
    const delimiter = /<<'([^']+)'/.exec(script)?.[1];
    expect(delimiter).toBeDefined();
    expect(content).not.toContain(delimiter!);
  });

  it("本文が改行で終わらなくても終端行が本文と地続きにならない", () => {
    const script = generateCliScript([file("a.md", "最後の行に改行が無い")]);

    expect(heredocTerminatorsAreValid(script)).toBe(true);
    expect(script).not.toContain("最後の行に改行が無いSCORIA_EOF");
  });

  it("本文が空でも壊れたヒアドキュメントを作らない", () => {
    const script = generateCliScript([file("a.md", "")]);

    expect(heredocTerminatorsAreValid(script)).toBe(true);
  });

  it("区切り語が行の途中に現れるだけなら終端と誤認されない", () => {
    // 行頭でない出現はシェルの終端条件を満たさないので、切り替えは不要でも壊れてはいけない
    const script = generateCliScript([file("a.md", "前置き SCORIA_EOF 後置き\n")]);

    expect(heredocTerminatorsAreValid(script)).toBe(true);
  });

  it("生成物のすべてのファイルを1本のスクリプトで復元できる形になっている", () => {
    const files = [
      file(".claude/skills/x/SKILL.md", "---\nname: x\n---\n\n本文\n"),
      file(".claude-plugin/plugin.json", '{\n  "name": "x"\n}\n'),
      file("README.md", "# x\n"),
    ];
    const script = generateCliScript(files);

    for (const f of files) {
      expect(script).toContain(`> ${f.path}`);
    }
    expect(heredocTerminatorsAreValid(script)).toBe(true);
  });
});
