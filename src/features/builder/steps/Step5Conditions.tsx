import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { useWizardStore } from "@/stores/wizardStore";
import { PRESET_DATABASES, DATABASE_CATEGORY_LABELS, ALL_DATABASE_IDS } from "@/lib/databases";
import type { DatabaseCategory } from "@/types";

const categories: DatabaseCategory[] = [
  "multidisciplinary_intl",
  "field_specific_intl",
  "tool",
  "domestic_jp",
  "patent",
];

export function Step5Conditions() {
  const {
    formData,
    setOutputLanguage,
    setYearRange,
    toggleDatabase,
    setAllDatabases,
  } = useWizardStore();

  const enabledIds = formData.conditions.enabledDatabaseIds;

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-foreground">詳細条件</h3>
        <p className="mt-1 text-sm text-muted-foreground">
          出力言語、対象期間、検索DBを設定します
        </p>
      </div>

      <div className="space-y-2">
        <Label>出力言語</Label>
        <div className="flex gap-3">
          {(["ja", "en"] as const).map((lang) => (
            <button
              key={lang}
              type="button"
              onClick={() => setOutputLanguage(lang)}
              className={`rounded-lg border px-4 py-2 text-sm transition-colors ${
                formData.conditions.outputLanguage === lang
                  ? "border-primary bg-primary/5 text-primary"
                  : "border-border text-muted-foreground hover:bg-muted/50"
              }`}
            >
              {lang === "ja" ? "日本語" : "English"}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-2">
        <Label>対象期間</Label>
        <div className="flex items-center gap-2">
          <Input
            type="number"
            placeholder="開始年"
            value={formData.conditions.yearRange.from ?? ""}
            onChange={(e) =>
              setYearRange(
                e.target.value ? Number(e.target.value) : null,
                formData.conditions.yearRange.to,
              )
            }
            className="w-28"
          />
          <span className="text-muted-foreground">〜</span>
          <Input
            type="number"
            placeholder="終了年"
            value={formData.conditions.yearRange.to ?? ""}
            onChange={(e) =>
              setYearRange(
                formData.conditions.yearRange.from,
                e.target.value ? Number(e.target.value) : null,
              )
            }
            className="w-28"
          />
        </div>
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label>検索DB</Label>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setAllDatabases([...ALL_DATABASE_IDS])}
            >
              すべて選択
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setAllDatabases([])}
            >
              すべて解除
            </Button>
          </div>
        </div>
        <ScrollArea className="h-56 rounded-lg border border-border">
          <div className="p-3">
            <Accordion type="multiple" defaultValue={categories}>
              {categories.map((cat) => {
                const dbs = PRESET_DATABASES.filter(
                  (db) => db.category === cat,
                );
                const count = dbs.filter((db) =>
                  enabledIds.includes(db.id),
                ).length;
                return (
                  <AccordionItem key={cat} value={cat}>
                    <AccordionTrigger className="text-xs">
                      <span className="flex items-center gap-1.5">
                        {DATABASE_CATEGORY_LABELS[cat]}
                        <Badge variant="secondary" className="text-[10px]">
                          {count}/{dbs.length}
                        </Badge>
                      </span>
                    </AccordionTrigger>
                    <AccordionContent>
                      <div className="space-y-1">
                        {dbs.map((db) => (
                          <div
                            key={db.id}
                            className="flex items-center justify-between py-1"
                          >
                            <span className="text-xs text-foreground">
                              {db.name}
                            </span>
                            <Switch
                              checked={enabledIds.includes(db.id)}
                              onCheckedChange={() => toggleDatabase(db.id)}
                            />
                          </div>
                        ))}
                      </div>
                    </AccordionContent>
                  </AccordionItem>
                );
              })}
            </Accordion>
          </div>
        </ScrollArea>
      </div>
    </div>
  );
}
