import { cn } from "@/lib/utils";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { useWizardStore } from "@/stores/wizardStore";
import { TEMPLATES } from "@/lib/constants";
import { TEMPLATE_CONTENTS, TEMPLATE_CONTENTS_EN } from "@/lib/templates";
import type { TemplateId } from "@/types";

export function Step2Template() {
  const { formData, setTemplateId, setName, setDescription, setOutputLanguage } =
    useWizardStore();
  const { extensionType, outputLanguage } = formData;

  const filteredTemplates = TEMPLATES.filter(
    (t) => !extensionType || t.supportedTypes.includes(extensionType),
  );

  const getTemplateMap = (lang: "ja" | "en") =>
    lang === "en" ? TEMPLATE_CONTENTS_EN : TEMPLATE_CONTENTS;

  const handleTemplateSelect = (id: TemplateId) => {
    setTemplateId(id);
    if (extensionType) {
      const content = getTemplateMap(outputLanguage)[id][extensionType];
      if (content) {
        setName(content.defaultName);
        setDescription(content.defaultDescription);
      }
    }
  };

  const handleLanguageChange = (lang: "ja" | "en") => {
    setOutputLanguage(lang);
    if (formData.templateId && extensionType) {
      const content = getTemplateMap(lang)[formData.templateId][extensionType];
      if (content) {
        setDescription(content.defaultDescription);
      }
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">テンプレート & 基本設定</h2>
        <p className="text-sm text-muted-foreground">
          学術テンプレートを選択し、基本情報を設定してください
        </p>
      </div>

      <div className="grid grid-cols-2 gap-2">
        {filteredTemplates.map((tmpl) => {
          const isSelected = formData.templateId === tmpl.id;
          return (
            <button
              key={tmpl.id}
              onClick={() => handleTemplateSelect(tmpl.id)}
              className={cn(
                "rounded-lg border p-3 text-left text-sm transition-colors",
                isSelected
                  ? "border-primary bg-primary/5"
                  : "border-border hover:border-primary/50",
              )}
            >
              <div className="font-medium">{tmpl.labelJa}</div>
              <div className="mt-1 text-xs text-muted-foreground line-clamp-2">
                {tmpl.descriptionJa}
              </div>
            </button>
          );
        })}
      </div>

      <div className="space-y-3">
        <div>
          <Label>出力言語</Label>
          <div className="mt-1 flex gap-1">
            <Button
              type="button"
              size="sm"
              variant={outputLanguage === "ja" ? "default" : "outline"}
              onClick={() => handleLanguageChange("ja")}
            >
              日本語
            </Button>
            <Button
              type="button"
              size="sm"
              variant={outputLanguage === "en" ? "default" : "outline"}
              onClick={() => handleLanguageChange("en")}
            >
              English
            </Button>
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            生成されるファイルの内容の言語を選択します
          </p>
        </div>

        <div>
          <Label htmlFor="ext-name">名前（slug）</Label>
          <Input
            id="ext-name"
            value={formData.name}
            onChange={(e) => setName(e.target.value)}
            placeholder="my-skill"
            className="mt-1"
          />
          <p className="mt-1 text-xs text-muted-foreground">
            半角英数字とハイフンのみ（例: literature-review）
          </p>
        </div>
        <div>
          <Label htmlFor="ext-desc">説明</Label>
          <Textarea
            id="ext-desc"
            value={formData.description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="この拡張の説明を入力..."
            rows={3}
            className="mt-1"
          />
        </div>
      </div>
    </div>
  );
}
