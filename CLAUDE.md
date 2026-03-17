# CLAUDE.md

このファイルは Claude Code がこのリポジトリで作業する際のガイドです。

## プロジェクト概要

**Scoria** — 研究テーマや目的を入力すると、学術検索や文献レビューに最適なAIプロンプトを自動生成するツール。

## 技術スタック

- **言語:** TypeScript
- **ランタイム:** Node.js
- **テスト:** Vitest
- **リンター:** ESLint (flat config)
- **フォーマッター:** Prettier

## よく使うコマンド

```bash
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
src/           # ソースコード (.ts)
  index.ts     # エントリーポイント
  *.test.ts    # テストファイル (ソースと同じディレクトリに配置)
dist/          # ビルド出力 (git管理外)
```

## コーディング規約

- 文字列はダブルクォート (`"`)
- セミコロンあり
- インデントはスペース2つ
- 末尾カンマあり (`trailingComma: "all"`)
- 1行の最大幅は100文字
- テストファイルはソースと同じディレクトリに `*.test.ts` として配置
- `strict: true` の TypeScript 設定を使用
