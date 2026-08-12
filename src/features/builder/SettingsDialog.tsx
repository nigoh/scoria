import { useState } from "react";
import { Gear } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useSettingsStore } from "@/stores/settingsStore";
import { AI_MODELS, type AiModelId } from "@/lib/ai/client";

/**
 * BYOK 設定（ADR-0027）。API キーはこの端末の localStorage にのみ保存され、
 * 送信先は Anthropic API だけ。ダイアログにもその旨を明示する。
 */
export function SettingsDialog() {
  const { apiKey, aiModel, setApiKey, setAiModel, clearApiKey } = useSettingsStore();
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="ghost" size="sm" className="gap-1.5" aria-label="設定">
          <Gear size={14} />
          設定
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>AI 設計の設定</DialogTitle>
          <DialogDescription className="font-sans">
            AI 設計（ベータ）はあなた自身の Anthropic API キーで動きます。 キーはこのブラウザの
            localStorage にのみ保存され、Anthropic API 以外には送信されません。
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div>
            <Label htmlFor="anthropic-api-key">Anthropic API キー</Label>
            <Input
              id="anthropic-api-key"
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="sk-ant-..."
              autoComplete="off"
              className="mt-1"
            />
            <p className="mt-1 font-sans text-xs text-muted-foreground">
              取得は console.anthropic.com から。API 利用料はキーの持ち主に請求されます。 共有 PC
              では使い終わったら削除してください。
            </p>
          </div>
          <div>
            <Label>モデル</Label>
            <Select value={aiModel} onValueChange={(v) => setAiModel(v as AiModelId)}>
              <SelectTrigger className="mt-1">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {AI_MODELS.map((m) => (
                  <SelectItem key={m.id} value={m.id}>
                    {m.labelJa}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex justify-between">
            <Button variant="outline" size="sm" onClick={clearApiKey} disabled={apiKey === ""}>
              キーを削除
            </Button>
            <Button size="sm" onClick={() => setOpen(false)}>
              完了
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
