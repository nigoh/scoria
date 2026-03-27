# CLAUDE.md

このファイルは Claude Code がこのリポジトリで作業する際のガイドです。

## プロジェクト概要

**Scoria** — 学術研究に特化した Claude Code のスキル・エージェント・プラグインをウィザード形式で自動生成し、ZIPでダウンロードできるツール。

## 技術スタック

- **フレームワーク:** Vite + React
- **言語:** TypeScript
- **UIライブラリ:** shadcn/ui（Radix UI ベース）
- **スタイリング:** Tailwind CSS v4
- **アイコン:** Phosphor Icons（@phosphor-icons/react）
- **テスト:** Vitest
- **リンター:** ESLint (flat config)
- **フォーマッター:** Prettier
- **デプロイ:** Cloudflare Pages

## よく使うコマンド

```bash
# 開発サーバー
npm run dev

# ビルド
npm run build

# テスト
npm test              # 全テスト実行
npm run test:watch    # ウォッチモードでテスト

# リント・フォーマット
npm run lint          # ESLint チェック
npm run lint:fix      # ESLint 自動修正
npm run format        # Prettier で整形
npm run format:check  # Prettier フォーマットチェック

# 型チェック
npm run typecheck
```

## ディレクトリ構成

```
index.html            # Vite エントリーポイント
public/               # 静的ファイル（_redirects, _headers）
src/
  main.tsx            # React エントリーポイント
  App.tsx             # ルートコンポーネント
  index.css           # グローバルCSS + デザイントークン
  vite-env.d.ts       # Vite 型宣言
  lib/
    utils.ts          # cn() ユーティリティ
    generator.ts      # Claude Code 拡張ファイル生成ロジック
    templates.ts      # 学術テンプレート定義
    constants.ts      # 定数（拡張タイプ、ツール一覧等）
    zip.ts            # JSZip によるZIP生成
    *.test.ts         # テストファイル
  components/
    ui/               # shadcn/ui コンポーネント
    theme-provider.tsx
    theme-toggle.tsx
dist/                 # ビルド出力 (git管理外)
```

## コーディング規約

- 文字列はダブルクォート (`"`)
- セミコロンあり
- インデントはスペース2つ
- 末尾カンマあり (`trailingComma: "all"`)
- 1行の最大幅は100文字
- テストファイルはソースと同じディレクトリに `*.test.ts` として配置
- `strict: true` の TypeScript 設定を使用
- パスエイリアス `@/` で `src/` を参照
