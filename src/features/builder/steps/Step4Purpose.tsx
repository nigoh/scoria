import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useWizardStore } from "@/stores/wizardStore";

export function Step4Purpose() {
  const { formData, setPurpose } = useWizardStore();

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-foreground">
          研究目的を入力
        </h3>
        <p className="mt-1 text-sm text-muted-foreground">
          プロンプトのタスク部分に反映されます。具体的に書くほど質の高いプロンプトが生成されます。
        </p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="purpose">研究目的</Label>
        <Textarea
          id="purpose"
          placeholder="例: LLMを用いた学術文献要約の精度向上に関する手法を比較し、今後の研究課題を特定したい"
          value={formData.purpose}
          onChange={(e) => setPurpose(e.target.value)}
          rows={4}
          maxLength={500}
        />
        <p className="text-right text-xs text-muted-foreground">
          {formData.purpose.length} / 500
        </p>
      </div>
    </div>
  );
}
