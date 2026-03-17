import { ThemeProvider } from "@/components/theme-provider";
import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { MagnifyingGlass } from "@phosphor-icons/react";

export function App() {
  return (
    <ThemeProvider>
      <div className="min-h-screen bg-background">
        <header className="flex items-center justify-between border-b border-border px-6 py-4">
          <h1 className="text-xl font-bold text-foreground">Scoria</h1>
          <ThemeToggle />
        </header>
        <main className="mx-auto max-w-6xl px-6 py-16">
          <div className="mb-12 text-center">
            <h2 className="text-4xl font-bold leading-tight text-foreground">
              知の地層から、最適な問いを掘り出す
            </h2>
            <p className="mt-4 text-lg text-muted-foreground">
              研究テーマや目的を入力すると、学術検索や文献レビューに最適なAIプロンプトを自動生成します。
            </p>
          </div>
          <div className="grid gap-8 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>デザインシステム確認</CardTitle>
                <CardDescription>
                  ボタン、カード、入力フィールドの動作確認用
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <Input placeholder="研究テーマを入力..." />
                <div className="flex flex-wrap gap-3">
                  <Button>
                    <MagnifyingGlass size={16} />
                    プロンプト生成
                  </Button>
                  <Button variant="secondary">コピー</Button>
                  <Button variant="outline">設定</Button>
                  <Button variant="ghost">キャンセル</Button>
                  <Button variant="destructive">削除</Button>
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle>カラーパレット</CardTitle>
                <CardDescription>
                  モノトーン基調 + セージグリーン（アクセント）
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-4 gap-3">
                  <div className="flex flex-col items-center gap-1">
                    <div className="h-10 w-10 rounded-lg bg-primary" />
                    <span className="text-xs text-muted-foreground">
                      Primary
                    </span>
                  </div>
                  <div className="flex flex-col items-center gap-1">
                    <div className="h-10 w-10 rounded-lg bg-secondary" />
                    <span className="text-xs text-muted-foreground">
                      Secondary
                    </span>
                  </div>
                  <div className="flex flex-col items-center gap-1">
                    <div className="h-10 w-10 rounded-lg bg-destructive" />
                    <span className="text-xs text-muted-foreground">
                      Destructive
                    </span>
                  </div>
                  <div className="flex flex-col items-center gap-1">
                    <div className="h-10 w-10 rounded-lg bg-muted" />
                    <span className="text-xs text-muted-foreground">Muted</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </div>
    </ThemeProvider>
  );
}
