import { nanoid } from "nanoid";
import { Plus, Trash } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useWizardStore } from "@/stores/wizardStore";
import { HOOK_EVENTS, HOOK_TYPES, HOOK_PRESETS } from "@/lib/constants";
import type { HookEntry, HookType } from "@/types";

export function HooksEditor() {
  const { formData, setHookEntries } = useWizardStore();
  const { hookEntries } = formData;

  const addEntry = () => {
    const entry: HookEntry = {
      id: nanoid(),
      event: "PostToolUse",
      matcher: "*",
      hookType: "command",
      command: "",
      url: "",
      prompt: "",
      timeout: 10000,
    };
    setHookEntries([...hookEntries, entry]);
  };

  const addFromPreset = (presetIndex: number) => {
    const preset = HOOK_PRESETS[presetIndex];
    const entry: HookEntry = {
      id: nanoid(),
      event: preset.event,
      matcher: preset.matcher,
      hookType: preset.hookType,
      command: preset.command,
      url: "",
      prompt: "",
      timeout: 10000,
    };
    setHookEntries([...hookEntries, entry]);
  };

  const updateEntry = (id: string, patch: Partial<HookEntry>) => {
    setHookEntries(hookEntries.map((e) => (e.id === id ? { ...e, ...patch } : e)));
  };

  const removeEntry = (id: string) => {
    setHookEntries(hookEntries.filter((e) => e.id !== id));
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <Label className="text-sm font-medium">フックエントリ</Label>
        <div className="flex gap-1">
          <Select onValueChange={(v) => addFromPreset(Number(v))}>
            <SelectTrigger className="h-7 w-auto gap-1 text-xs">
              <SelectValue placeholder="プリセット" />
            </SelectTrigger>
            <SelectContent>
              {HOOK_PRESETS.map((p, i) => (
                <SelectItem key={i} value={String(i)}>
                  {p.labelJa}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button variant="outline" size="sm" className="h-7 gap-1 text-xs" onClick={addEntry}>
            <Plus size={12} />
            追加
          </Button>
        </div>
      </div>

      {hookEntries.length === 0 ? (
        <p className="py-4 text-center text-xs text-muted-foreground">
          フックエントリがありません。プリセットから追加するか、空のエントリを追加してください。
        </p>
      ) : (
        <div className="space-y-3">
          {hookEntries.map((entry) => (
            <div key={entry.id} className="space-y-2 rounded-lg border p-3">
              <div className="flex items-start justify-between gap-2">
                <div className="grid flex-1 grid-cols-2 gap-2">
                  <div>
                    <Label className="text-xs">イベント</Label>
                    <Select
                      value={entry.event}
                      onValueChange={(v) => updateEntry(entry.id, { event: v })}
                    >
                      <SelectTrigger className="mt-1 h-8 text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {HOOK_EVENTS.map((e) => (
                          <SelectItem key={e} value={e}>
                            {e}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label className="text-xs">マッチャー</Label>
                    <Input
                      value={entry.matcher}
                      onChange={(e) => updateEntry(entry.id, { matcher: e.target.value })}
                      placeholder="Edit|Write"
                      className="mt-1 h-8 text-xs"
                    />
                  </div>
                </div>
                <Button
                  variant="ghost"
                  size="sm"
                  className="mt-4 h-8 w-8 shrink-0 p-0 text-muted-foreground hover:text-destructive"
                  onClick={() => removeEntry(entry.id)}
                >
                  <Trash size={14} />
                </Button>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <Label className="text-xs">タイプ</Label>
                  <Select
                    value={entry.hookType}
                    onValueChange={(v) => updateEntry(entry.id, { hookType: v as HookType })}
                  >
                    <SelectTrigger className="mt-1 h-8 text-xs">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {HOOK_TYPES.map((t) => (
                        <SelectItem key={t} value={t}>
                          {t}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label className="text-xs">タイムアウト (ms)</Label>
                  <Input
                    type="number"
                    value={entry.timeout}
                    onChange={(e) => updateEntry(entry.id, { timeout: Number(e.target.value) })}
                    className="mt-1 h-8 text-xs"
                  />
                </div>
              </div>

              {entry.hookType === "command" && (
                <div>
                  <Label className="text-xs">コマンド</Label>
                  <Input
                    value={entry.command}
                    onChange={(e) => updateEntry(entry.id, { command: e.target.value })}
                    placeholder="./scripts/validate.sh"
                    className="mt-1 h-8 text-xs"
                  />
                </div>
              )}

              {entry.hookType === "http" && (
                <div>
                  <Label className="text-xs">URL</Label>
                  <Input
                    value={entry.url}
                    onChange={(e) => updateEntry(entry.id, { url: e.target.value })}
                    placeholder="https://example.com/webhook"
                    className="mt-1 h-8 text-xs"
                  />
                </div>
              )}

              {(entry.hookType === "prompt" || entry.hookType === "agent") && (
                <div>
                  <Label className="text-xs">プロンプト</Label>
                  <Input
                    value={entry.prompt}
                    onChange={(e) => updateEntry(entry.id, { prompt: e.target.value })}
                    placeholder="Check this file for issues..."
                    className="mt-1 h-8 text-xs"
                  />
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
