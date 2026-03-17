import { useState } from "react";
import { Copy, CheckCircle } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";

interface CopyButtonProps {
  text: string;
}

export function CopyButton({ text }: CopyButtonProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <Button
      variant="secondary"
      size="sm"
      onClick={handleCopy}
      disabled={!text}
      className="gap-1.5"
    >
      {copied ? (
        <>
          <CheckCircle size={16} className="text-primary" />
          コピー済み
        </>
      ) : (
        <>
          <Copy size={16} />
          コピー
        </>
      )}
    </Button>
  );
}
