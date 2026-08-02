# Scoria

研究テーマと目的を入力すると、**Claude Code のスキル・エージェント・プラグイン**をウィザードで生成し、
ZIP でダウンロードできる Web アプリ。学術研究（系統的レビュー・メタ分析・引用チェック等）の
テンプレートを内蔵する。

## できること

- **4ステップのウィザード**: 拡張タイプ → テンプレート → 設定 → 内容編集
- **3種類の拡張を生成**: スキル（`SKILL.md`）／エージェント（`.md`）／プラグイン（`plugin.json` + 一式）
- **frontmatter を細かく指定**: 許可ツール・モデル・effort・isolation・paths など
- **Hooks / MCP サーバーのエディタ**: プラグインにフックと MCP 設定を同梱できる
- **出力形式**: ZIP ダウンロード／クリップボードへコピー／CLI コマンドとして書き出し
- **履歴**: 生成した拡張を保存して再編集できる
- 日本語・英語の両方で出力できる

## 開発

```bash
npm ci
npm run dev             # 開発サーバー
npm run build           # 本番ビルド

bash scripts/check.sh   # 品質ゲート（型・リント・整形・テスト＋土台の自己検証）
```

`scripts/check.sh` が品質ゲートの唯一の入口で、Stop フックと CI が同じものを実行する。
ゲートを足すときは check.sh に足す（フックや CI に直書きしない）。

## リポジトリ内の道しるべ

- Claude Code 向けの恒常事実（構成・スキル・エージェント一覧）: [CLAUDE.md](CLAUDE.md)
- 開発規約（ブランチ・コミット・PR・ラウンド運用）: [CONTRIBUTING.md](CONTRIBUTING.md)
- steering の案内: [.claude/README.md](.claude/README.md)
- 意思決定記録: [docs/adr/README.md](docs/adr/README.md)
- 開発プロセス定義: [docs/process/README.md](docs/process/README.md)
- 開発基盤スクリプトのリファレンス: `docs/reference.html`（`scripts/build-docs.sh` が生成）

## 技術スタック

Vite / React 19 / TypeScript (strict) / Tailwind CSS v4 / shadcn/ui (Radix) / zustand /
react-router-dom v7 / JSZip / Vitest / Playwright。デプロイは Cloudflare Pages。

## 開発の土台について

開発の進め方（品質ゲート・steering・V字プロセス・ADR 運用）は [nigoh/deb](https://github.com/nigoh/deb)
から移植している（[ADR-0024](docs/adr/0024-adopt-deb-foundation-and-stack-gates.md) /
[ADR-0025](docs/adr/0025-exclude-companion-plugin-and-retarget-doc-gates.md)）。
土台そのものへの改善提案は `/feedback` で本家へ送る（ADR-0009）。

## ライセンス

[MIT License](LICENSE)
