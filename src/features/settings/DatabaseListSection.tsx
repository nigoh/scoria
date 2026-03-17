import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { ScrollArea } from "@/components/ui/scroll-area";
import { DatabaseItem } from "./DatabaseItem";
import { useSettingsStore } from "@/stores/settingsStore";
import { PRESET_DATABASES, DATABASE_CATEGORY_LABELS } from "@/lib/databases";
import type { DatabaseCategory } from "@/types";

const categories: DatabaseCategory[] = [
  "multidisciplinary_intl",
  "field_specific_intl",
  "tool",
  "domestic_jp",
  "patent",
];

export function DatabaseListSection() {
  const { settings, toggleDatabase, enableAllDatabases, disableAllDatabases } =
    useSettingsStore();
  const enabledIds = settings.enabledDatabaseIds;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          プロンプト生成時に考慮する検索DBを選択してください
        </p>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={enableAllDatabases}>
            すべて有効
          </Button>
          <Button variant="outline" size="sm" onClick={disableAllDatabases}>
            すべて無効
          </Button>
        </div>
      </div>

      <ScrollArea className="h-[480px] rounded-lg border border-border">
        <div className="p-4">
          <Accordion type="multiple" defaultValue={categories}>
            {categories.map((cat) => {
              const dbs = PRESET_DATABASES.filter((db) => db.category === cat);
              const enabledCount = dbs.filter((db) =>
                enabledIds.includes(db.id),
              ).length;
              return (
                <AccordionItem key={cat} value={cat}>
                  <AccordionTrigger>
                    <div className="flex items-center gap-2">
                      <span>{DATABASE_CATEGORY_LABELS[cat]}</span>
                      <Badge variant="secondary" className="text-[10px]">
                        {enabledCount} / {dbs.length}
                      </Badge>
                    </div>
                  </AccordionTrigger>
                  <AccordionContent>
                    <div className="space-y-1">
                      {dbs.map((db) => (
                        <DatabaseItem
                          key={db.id}
                          database={db}
                          enabled={enabledIds.includes(db.id)}
                          onToggle={() => toggleDatabase(db.id)}
                        />
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
  );
}
