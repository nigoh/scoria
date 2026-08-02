---
paths:
  - "src/**"
  - "e2e/**"
---

# フロントエンドの規約（src/ · e2e/ を編集中に自動ロードされる。ADR-0024）

Vite + React 19 + TypeScript(strict)。テストの厳格度は `.claude/rules/tdd.md` を併読する。

## レイヤと依存の向き

依存は**下から上へ一方向**。逆流させない（循環と「UI からしか呼べないロジック」を防ぐ）。

```
routes/      ルーティングとページ合成。ロジックを持たない
  ↓
features/    画面機能（home / builder）。stores と lib を束ねて UI にする
  ↓
components/  再利用 UI。ui/ は shadcn/ui、layout/ は骨組み、illustrations/ は SVG
  ↓
stores/      zustand。画面をまたぐ状態のみ。1画面で閉じる状態は useState に置く
  ↓
lib/         純粋ロジック（generator / templates / constants / cli / zip / utils）
types/       全層が参照する型。ここは何にも依存しない
```

- `lib/` は **React に依存しない**（`import` に react を出さない）。DOM API とブラウザ専用 API も
  `zip.ts` のようなダウンロード境界に閉じ込め、生成ロジック側へ漏らさない
- `components/ui/` は shadcn/ui の生成物。原則そのまま使い、独自の見た目は呼び出し側で `className` を渡す
- 画面をまたがない一時状態を `stores/` に置かない（ストアが肥大して差分が読めなくなる）

## テスト

- **`lib/` は純粋ロジックなので test-first を標準リズムにする**（ADR-0013）。
  生成物の中身（frontmatter・ファイルパス・ZIP の構成）は入出力が固定できるので、
  仕様を先にテストへ書いてから実装する
- `*.test.ts` はソースと同じディレクトリに置く（`src/lib/generator.test.ts` の形）
- **生成ロジックの回帰はスナップショットで固定しない**。何が変わったか読めない差分は
  レビューできず、壊れたまま更新されやすい。キー項目を名指しでアサートする
- 画面横断の振る舞い（ウィザードを最後まで通す・ZIP が落ちてくる）は `e2e/` の Playwright で見る
- 要件 ID がある実装のテストには `Verifies: <ID>` を書く（`scripts/check-traceability.sh` が検査する）

## コーディング規約

- 文字列はダブルクォート、セミコロンあり、インデント2スペース、末尾カンマあり、1行100文字まで
  （`.prettierrc` が正本。`npm run format` で整形し、`format:check` が品質ゲートに載っている）
- パスエイリアス `@/` で `src/` を参照する（相対パスの `../../` を積み上げない）
- 型は `src/types/index.ts` に集約する。機能ごとに同じ形の型を再定義しない
- `any` を入れない。外部入力の絞り込みは型ガードを書く（`strict: true` を弱めない）
