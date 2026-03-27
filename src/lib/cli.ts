import type { GeneratedFile } from "@/types";

/**
 * Generate a shell script that creates all files via heredoc.
 */
export function generateCliScript(files: GeneratedFile[]): string {
  if (files.length === 0) return "";

  const commands: string[] = [];

  for (const file of files) {
    const dir = file.path.includes("/")
      ? file.path.split("/").slice(0, -1).join("/")
      : null;

    const delimiter = file.content.includes("SCORIA_EOF")
      ? "SCORIA_END"
      : "SCORIA_EOF";

    if (dir) {
      commands.push(
        `mkdir -p ${dir} && cat <<'${delimiter}' > ${file.path}\n${file.content}${delimiter}`,
      );
    } else {
      commands.push(
        `cat <<'${delimiter}' > ${file.path}\n${file.content}${delimiter}`,
      );
    }
  }

  return commands.join("\n\n");
}
