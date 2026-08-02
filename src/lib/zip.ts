import JSZip from "jszip";
import type { GeneratedFile } from "@/types";

/**
 * 生成ファイル一覧を ZIP のバイト列にまとめる。
 *
 * ブラウザ API に触れないので、この関数だけを単体テストできる（`.claude/rules/frontend.md`:
 * ブラウザ専用 API はダウンロード境界に閉じ込め、生成ロジック側へ漏らさない）。
 */
export async function buildZipArchive(files: GeneratedFile[]): Promise<Uint8Array> {
  const zip = new JSZip();

  for (const file of files) {
    zip.file(file.path, file.content);
  }

  return zip.generateAsync({ type: "uint8array" });
}

/**
 * ZIP を組み立ててブラウザにダウンロードさせる。ここが DOM への唯一の境界。
 */
export async function downloadAsZip(files: GeneratedFile[], zipName: string): Promise<void> {
  const bytes = await buildZipArchive(files);
  const blob = new Blob([bytes as unknown as BlobPart], { type: "application/zip" });
  const url = URL.createObjectURL(blob);

  const a = document.createElement("a");
  a.href = url;
  a.download = `${zipName}.zip`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
