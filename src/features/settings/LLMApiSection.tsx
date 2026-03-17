import { useState } from "react";
import { Eye, EyeSlash } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useSettingsStore } from "@/stores/settingsStore";
import { ANTHROPIC_MODELS, OPENAI_MODELS } from "@/lib/constants";
import type { LLMProvider } from "@/types";

export function LLMApiSection() {
  const { settings, setActiveProvider, setApiKey, clearApiKey, setModel } =
    useSettingsStore();

  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">
        お使いのLLM APIキーを設定してください。キーはブラウザ内で暗号化保存され、外部に送信されません。
      </p>
      <Tabs
        value={settings.activeProvider}
        onValueChange={(v) => setActiveProvider(v as LLMProvider)}
      >
        <TabsList>
          <TabsTrigger value="anthropic">Anthropic</TabsTrigger>
          <TabsTrigger value="openai">OpenAI</TabsTrigger>
        </TabsList>
        <TabsContent value="anthropic">
          <ProviderForm
            provider="anthropic"
            models={ANTHROPIC_MODELS}
            config={settings.providers.anthropic}
            onSaveKey={(key) => setApiKey("anthropic", key)}
            onClearKey={() => clearApiKey("anthropic")}
            onModelChange={(model) => setModel("anthropic", model)}
          />
        </TabsContent>
        <TabsContent value="openai">
          <ProviderForm
            provider="openai"
            models={OPENAI_MODELS}
            config={settings.providers.openai}
            onSaveKey={(key) => setApiKey("openai", key)}
            onClearKey={() => clearApiKey("openai")}
            onModelChange={(model) => setModel("openai", model)}
          />
        </TabsContent>
      </Tabs>
    </div>
  );
}

interface ProviderFormProps {
  provider: LLMProvider;
  models: { id: string; name: string }[];
  config: { model: string; encryptedApiKey: string | null };
  onSaveKey: (key: string) => void;
  onClearKey: () => void;
  onModelChange: (model: string) => void;
}

function ProviderForm({
  provider,
  models,
  config,
  onSaveKey,
  onClearKey,
  onModelChange,
}: ProviderFormProps) {
  const [keyInput, setKeyInput] = useState("");
  const [showKey, setShowKey] = useState(false);
  const isConfigured = config.encryptedApiKey !== null;

  const handleSave = () => {
    if (keyInput.trim()) {
      onSaveKey(keyInput.trim());
      setKeyInput("");
    }
  };

  return (
    <div className="space-y-4 rounded-lg border border-border p-4">
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium">ステータス:</span>
        {isConfigured ? (
          <Badge variant="default">設定済み</Badge>
        ) : (
          <Badge variant="secondary">未設定</Badge>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor={`${provider}-model`}>モデル</Label>
        <Select value={config.model} onValueChange={onModelChange}>
          <SelectTrigger id={`${provider}-model`}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {models.map((m) => (
              <SelectItem key={m.id} value={m.id}>
                {m.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="space-y-2">
        <Label htmlFor={`${provider}-key`}>APIキー</Label>
        <div className="flex gap-2">
          <div className="relative flex-1">
            <Input
              id={`${provider}-key`}
              type={showKey ? "text" : "password"}
              placeholder={isConfigured ? "••••••••（設定済み）" : "sk-..."}
              value={keyInput}
              onChange={(e) => setKeyInput(e.target.value)}
            />
            <button
              type="button"
              className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              onClick={() => setShowKey(!showKey)}
            >
              {showKey ? <EyeSlash size={16} /> : <Eye size={16} />}
            </button>
          </div>
          <Button onClick={handleSave} disabled={!keyInput.trim()}>
            保存
          </Button>
        </div>
      </div>

      {isConfigured && (
        <Button variant="ghost" size="sm" onClick={onClearKey}>
          キーを削除
        </Button>
      )}
    </div>
  );
}
