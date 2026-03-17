import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useWizardStore } from "@/stores/wizardStore";
import { RESEARCH_FIELDS } from "@/lib/constants";

export function Step2Field() {
  const { formData, setField } = useWizardStore();

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-foreground">
          研究分野を選択
        </h3>
        <p className="mt-1 text-sm text-muted-foreground">
          分野に応じて最適な検索DBやプロンプトを調整します
        </p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="research-field">研究分野</Label>
        <Select value={formData.field ?? ""} onValueChange={setField}>
          <SelectTrigger id="research-field">
            <SelectValue placeholder="分野を選択してください" />
          </SelectTrigger>
          <SelectContent>
            {RESEARCH_FIELDS.map((field) => (
              <SelectItem key={field.id} value={field.id}>
                {field.labelJa}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
    </div>
  );
}
