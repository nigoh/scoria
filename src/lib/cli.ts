import type { GeneratedFile } from "@/types";

const BASE_DELIMITER = "SCORIA_EOF";

/**
 * 本文と衝突しないヒアドキュメントの区切り語を選ぶ。
 *
 * シェルがヒアドキュメントを閉じるのは「行頭に区切り語だけがある行」なので行の途中の出現は
 * 本来無害だが、判定を単純に保つため本文に一度でも現れる語は候補から外す。候補が尽きたら
 * 連番を足して必ず衝突しない語に到達させる（候補を2語に固定すると、本文に両方が含まれたときに
 * 閉じないスクリプトを黙って出力してしまう）。
 */
function pickDelimiter(content: string): string {
  if (!content.includes(BASE_DELIMITER)) return BASE_DELIMITER;
  for (let n = 1; ; n += 1) {
    const candidate = `${BASE_DELIMITER}_${n}`;
    if (!content.includes(candidate)) return candidate;
  }
}

/**
 * Generate a shell script that creates all files via heredoc.
 */
export function generateCliScript(files: GeneratedFile[]): string {
  if (files.length === 0) return "";

  const commands: string[] = [];

  for (const file of files) {
    const dir = file.path.includes("/") ? file.path.split("/").slice(0, -1).join("/") : null;
    const delimiter = pickDelimiter(file.content);

    // 終端は行頭に区切り語だけがある行でなければならない。本文が改行で終わらないままつなぐと
    // 終端が最終行と地続きになり、ヒアドキュメントが閉じない。
    const body = file.content && !file.content.endsWith("\n") ? `${file.content}\n` : file.content;
    const heredoc = `cat <<'${delimiter}' > ${file.path}\n${body}${delimiter}`;

    commands.push(dir ? `mkdir -p ${dir} && ${heredoc}` : heredoc);
  }

  return commands.join("\n\n");
}
