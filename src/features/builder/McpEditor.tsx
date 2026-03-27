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
import { MCP_TEMPLATES } from "@/lib/constants";
import type { McpServerEntry } from "@/types";

export function McpEditor() {
  const { formData, setMcpEntries } = useWizardStore();
  const { mcpEntries } = formData;

  const addFromTemplate = (templateIndex: number) => {
    const tmpl = MCP_TEMPLATES[templateIndex];
    const entry: McpServerEntry = {
      id: nanoid(),
      name: tmpl.name,
      command: tmpl.command,
      args: tmpl.args,
      env: "",
    };
    setMcpEntries([...mcpEntries, entry]);
  };

  const addEmpty = () => {
    const entry: McpServerEntry = {
      id: nanoid(),
      name: "my-server",
      command: "",
      args: "",
      env: "",
    };
    setMcpEntries([...mcpEntries, entry]);
  };

  const updateEntry = (id: string, patch: Partial<McpServerEntry>) => {
    setMcpEntries(mcpEntries.map((e) => (e.id === id ? { ...e, ...patch } : e)));
  };

  const removeEntry = (id: string) => {
    setMcpEntries(mcpEntries.filter((e) => e.id !== id));
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <Label className="text-sm font-medium">MCP サーバー</Label>
        <div className="flex gap-1">
          <Select onValueChange={(v) => addFromTemplate(Number(v))}>
            <SelectTrigger className="h-7 w-auto gap-1 text-xs">
              <SelectValue placeholder="テンプレート" />
            </SelectTrigger>
            <SelectContent>
              {MCP_TEMPLATES.map((t, i) => (
                <SelectItem key={i} value={String(i)}>
                  {t.labelJa}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button variant="outline" size="sm" className="h-7 gap-1 text-xs" onClick={addEmpty}>
            <Plus size={12} />
            追加
          </Button>
        </div>
      </div>

      {mcpEntries.length === 0 ? (
        <p className="py-4 text-center text-xs text-muted-foreground">
          MCP サーバーがありません。テンプレートから追加するか、空のエントリを追加してください。
        </p>
      ) : (
        <div className="space-y-3">
          {mcpEntries.map((entry) => (
            <div key={entry.id} className="space-y-2 rounded-lg border p-3">
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1">
                  <Label className="text-xs">サーバー名</Label>
                  <Input
                    value={entry.name}
                    onChange={(e) => updateEntry(entry.id, { name: e.target.value })}
                    placeholder="my-server"
                    className="mt-1 h-8 text-xs"
                  />
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
                  <Label className="text-xs">コマンド</Label>
                  <Input
                    value={entry.command}
                    onChange={(e) => updateEntry(entry.id, { command: e.target.value })}
                    placeholder="npx"
                    className="mt-1 h-8 text-xs"
                  />
                </div>
                <div>
                  <Label className="text-xs">引数</Label>
                  <Input
                    value={entry.args}
                    onChange={(e) => updateEntry(entry.id, { args: e.target.value })}
                    placeholder="@anthropic/mcp-pubmed"
                    className="mt-1 h-8 text-xs"
                  />
                </div>
              </div>

              <div>
                <Label className="text-xs">環境変数（KEY=VALUE 形式、改行区切り）</Label>
                <textarea
                  value={entry.env}
                  onChange={(e) => updateEntry(entry.id, { env: e.target.value })}
                  placeholder={"API_KEY=your-key\nBASE_URL=https://..."}
                  rows={2}
                  className="mt-1 w-full rounded-md border border-input bg-background px-3 py-1.5 text-xs ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
