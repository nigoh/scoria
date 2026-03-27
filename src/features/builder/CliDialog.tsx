import { useState } from "react";
import { Terminal, Copy, Check } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { generateCliScript } from "@/lib/cli";
import { useExtensionStore } from "@/stores/extensionStore";

export function CliDialog() {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const { generatedExtension } = useExtensionStore();

  const files = generatedExtension?.files ?? [];
  const script = generateCliScript(files);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(script);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <>
      <Button
        variant="outline"
        size="sm"
        className="gap-1.5"
        disabled={files.length === 0}
        onClick={() => setOpen(true)}
      >
        <Terminal size={14} />
        CLI
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>CLIコマンド</DialogTitle>
            <DialogDescription>
              ターミナルに貼り付けてファイルを作成できます
            </DialogDescription>
          </DialogHeader>
          <div className="relative">
            <Button
              variant="ghost"
              size="sm"
              className="absolute right-2 top-2 z-10 gap-1 text-xs"
              onClick={handleCopy}
            >
              {copied ? <Check size={14} /> : <Copy size={14} />}
              {copied ? "コピー済み" : "コピー"}
            </Button>
            <ScrollArea className="h-80 rounded-md border bg-muted/50 p-4">
              <pre className="whitespace-pre-wrap font-mono text-xs leading-relaxed">
                {script}
              </pre>
            </ScrollArea>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
