import { useState } from "react";
import { DownloadSimple, CheckCircle } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { downloadAsZip } from "@/lib/zip";
import { useExtensionStore } from "@/stores/extensionStore";

export function DownloadButton() {
  const { generatedExtension } = useExtensionStore();
  const [downloaded, setDownloaded] = useState(false);

  const handleDownload = async () => {
    if (!generatedExtension || generatedExtension.files.length === 0) return;

    const firstPath = generatedExtension.files[0].path;
    const name = firstPath.split("/").find((p) => p !== ".claude" && p !== "") ?? "extension";

    await downloadAsZip(generatedExtension.files, `scoria-${name}`);
    setDownloaded(true);
    setTimeout(() => setDownloaded(false), 2000);
  };

  return (
    <Button
      variant="default"
      size="sm"
      onClick={handleDownload}
      disabled={!generatedExtension || generatedExtension.files.length === 0}
      className="gap-1.5"
    >
      {downloaded ? (
        <>
          <CheckCircle size={16} />
          ダウンロード済み
        </>
      ) : (
        <>
          <DownloadSimple size={16} />
          ZIPダウンロード
        </>
      )}
    </Button>
  );
}
