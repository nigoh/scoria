import { PageContainer } from "@/components/layout/PageContainer";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { LLMApiSection } from "@/features/settings/LLMApiSection";
import { DatabaseListSection } from "@/features/settings/DatabaseListSection";

export function Component() {
  return (
    <PageContainer>
      <h1 className="mb-8 text-2xl font-bold text-foreground">設定</h1>
      <Tabs defaultValue="llm">
        <TabsList>
          <TabsTrigger value="llm">LLM API設定</TabsTrigger>
          <TabsTrigger value="databases">検索DBリスト</TabsTrigger>
        </TabsList>
        <TabsContent value="llm">
          <LLMApiSection />
        </TabsContent>
        <TabsContent value="databases">
          <DatabaseListSection />
        </TabsContent>
      </Tabs>
    </PageContainer>
  );
}
