import { useState } from "react";
import { X, Plus } from "@phosphor-icons/react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import { useWizardStore } from "@/stores/wizardStore";

export function Step3Keywords() {
  const { formData, addKeyword, removeKeyword } = useWizardStore();
  const [input, setInput] = useState("");

  const handleAdd = () => {
    const value = input.trim();
    if (value) {
      addKeyword(value);
      setInput("");
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleAdd();
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-foreground">
          キーワードを入力
        </h3>
        <p className="mt-1 text-sm text-muted-foreground">
          研究テーマに関連するキーワードを追加してください（最大10件）
        </p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="keyword-input">キーワード</Label>
        <div className="flex gap-2">
          <Input
            id="keyword-input"
            placeholder="キーワードを入力..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={formData.keywords.length >= 10}
          />
          <Button
            onClick={handleAdd}
            disabled={!input.trim() || formData.keywords.length >= 10}
            size="icon"
          >
            <Plus size={16} />
          </Button>
        </div>
      </div>
      {formData.keywords.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {formData.keywords.map((kw) => (
            <Badge key={kw.id} variant="secondary" className="gap-1 pr-1">
              {kw.value}
              <button
                type="button"
                onClick={() => removeKeyword(kw.id)}
                className="ml-0.5 rounded-full p-0.5 hover:bg-muted-foreground/20"
              >
                <X size={12} />
              </button>
            </Badge>
          ))}
        </div>
      )}
      <p className="text-xs text-muted-foreground">
        {formData.keywords.length} / 10 件
      </p>
    </div>
  );
}
