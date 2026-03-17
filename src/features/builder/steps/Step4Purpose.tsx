import { useState } from "react";
import { Plus, X, Lightbulb, CaretRight } from "@phosphor-icons/react";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { useWizardStore } from "@/stores/wizardStore";

function DynList({
  items,
  onChange,
  placeholder,
  addLabel,
}: {
  items: string[];
  onChange: (items: string[]) => void;
  placeholder: string;
  addLabel: string;
}) {
  return (
    <div className="space-y-2">
      {items.map((item, i) => (
        <div key={i} className="flex items-center gap-2 group">
          <span className="w-5 text-center text-[10px] font-bold text-muted-foreground">
            {i + 1}
          </span>
          <Input
            value={item}
            onChange={(e) => {
              const next = [...items];
              next[i] = e.target.value;
              onChange(next);
            }}
            placeholder={`${placeholder} ${i + 1}`}
            className="flex-1"
          />
          {items.length > 1 && (
            <button
              type="button"
              onClick={() => onChange(items.filter((_, idx) => idx !== i))}
              className="flex h-7 w-7 items-center justify-center rounded-lg text-muted-foreground opacity-0 transition-opacity hover:bg-destructive/10 hover:text-destructive group-hover:opacity-100"
            >
              <X size={14} />
            </button>
          )}
        </div>
      ))}
      <Button
        variant="outline"
        size="sm"
        onClick={() => onChange([...items, ""])}
        className="w-full gap-1 border-dashed"
      >
        <Plus size={14} />
        {addLabel}
      </Button>
    </div>
  );
}

function Guide({
  title,
  description,
  tips,
}: {
  title: string;
  description: string;
  tips: string[];
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className="mb-2">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
      >
        <Lightbulb size={13} className="text-amber-400" />
        <span className="underline underline-offset-2 decoration-muted-foreground/30">
          {title}
        </span>
        <CaretRight
          size={12}
          className={`transition-transform ${open ? "rotate-90" : ""}`}
        />
      </button>
      {open && (
        <div className="mt-2 rounded-lg border border-border bg-muted/30 p-3 space-y-2">
          <p className="text-xs text-muted-foreground leading-relaxed border-l-2 border-amber-300 pl-2">
            {description}
          </p>
          {tips.map((tip, i) => (
            <p key={i} className="text-xs text-muted-foreground pl-3">
              • {tip}
            </p>
          ))}
        </div>
      )}
    </div>
  );
}

export function Step4Purpose() {
  const {
    formData,
    setPurpose,
    setComparisonItems,
    setComparisonAxes,
  } = useWizardStore();

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-foreground">
          研究目的・比較設定
        </h3>
        <p className="mt-1 text-sm text-muted-foreground">
          研究目的と、必要に応じて比較項目・比較軸を設定します。
        </p>
      </div>

      {/* 研究目的 */}
      <div className="space-y-2">
        <Label htmlFor="purpose">研究目的</Label>
        <Textarea
          id="purpose"
          placeholder="例: LLMを用いた学術文献要約の精度向上に関する手法を比較し、今後の研究課題を特定したい"
          value={formData.purpose}
          onChange={(e) => setPurpose(e.target.value)}
          rows={3}
          maxLength={500}
        />
        <p className="text-right text-xs text-muted-foreground">
          {formData.purpose.length} / 500
        </p>
      </div>

      <Separator />

      {/* 比較項目 */}
      <div className="space-y-2">
        <Label>比較項目（任意）</Label>
        <Guide
          title="何を入力すればいい？"
          description="マトリクスの「行」になる要素。比較したい手法・ツール・条件・介入方法を入れます。"
          tips={[
            "同カテゴリ内で並列比較できるものを選ぶ",
            "2〜6個が読みやすい目安",
            "対照群（従来手法/何もしない）を1つ入れると効果が明確に",
          ]}
        />
        <DynList
          items={formData.comparisonItems}
          onChange={setComparisonItems}
          placeholder="比較項目"
          addLabel="項目を追加"
        />
      </div>

      <Separator />

      {/* 比較軸 */}
      <div className="space-y-2">
        <Label>比較軸（任意）</Label>
        <Guide
          title="何を入力すればいい？"
          description="マトリクスの「列」にあたる評価軸。各項目を「何の観点で」評価するかを指定します。"
          tips={[
            "定量化しやすい指標を優先",
            "アウトカム（結果）とプロセス（過程）を混ぜるとバランスが良い",
            "空欄でもOK — AIが自動提案します",
          ]}
        />
        <DynList
          items={formData.comparisonAxes}
          onChange={setComparisonAxes}
          placeholder="比較軸"
          addLabel="軸を追加"
        />
      </div>
    </div>
  );
}
