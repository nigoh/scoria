---
name: stack-init
description: >
  この土台リポジトリに具体的な技術スタック（Node/TypeScript、Python、その他）を導入する初期化スキル。
  スタック選定を ADR 化し、品質ゲート（scripts/check.sh）へ typecheck/lint/test を配線し、
  領域別 rules と CLAUDE.md を更新する。アプリ開発を始めるときに最初に一度だけ使う。
disable-model-invocation: true
argument-hint: "[導入したいスタックの概要]"
---

# スタック導入手順

この土台はスタック非依存（ADR-0003）。アプリ開発を始めるときにこのスキルで具体化する。

## 1. 選定

- `$ARGUMENTS` と会話からスタック候補を整理し、AskUserQuestion で確定する
  （言語 / フレームワーク / パッケージマネージャ / テストランナー / リンタ・フォーマッタ）
- 迷いのある選定は `/adr` で ADR 化する（≥2案の比較付き）。自明な場合も採用スタックの ADR を1本残す

## 2. 足場の作成

- 選定したスタックの標準的な初期化を行う（例: `pnpm init` + tsconfig strict、`uv init` 等）
- `.gitignore` にスタック固有の生成物を追記する
- 最新の安定バージョンを使う。バージョン・設定の根拠が必要なら Context7 / 公式ドキュメントで確認する

## 3. 品質ゲートへの配線（最重要）

- `scripts/check.sh` の「スタック固有のゲート」セクションに typecheck / lint / test を追記する
  （Stop フックと CI は check.sh を呼ぶだけなので、これだけで両方に効く）
- テストが1本も無い状態を作らない。サンプルでもよいので green のテストを1本置く
- 可能なら定量品質ゲート（テスト網羅率の閾値など、`docs/process/verification.md`）を check.sh に足す
- テストは `Verifies: <要件ID>` を書ける形にし、`check-traceability.sh` の要件被覆検証が効くようにする

## 4. steering の更新

- 領域別規約を `.claude/rules/` に path スコープで追加する（例: `src/**` のレイヤ規約）
- ビルド・テストコマンドと構成マップを CLAUDE.md に追記する（200行未満を維持）
- 必要なら専門エージェント（reviewer 系）やスキルを追加し、CLAUDE.md の一覧と同期する
- 生成物（ビルド出力・自動生成ファイル）ができたら `.claude/hooks/guard-protected.sh` に保護対象として追記し、`scripts/test-hooks.sh` にブロック/許可の再発防止ケースを併設する

## 5. 検証

- `bash scripts/check.sh` が緑であること（スタックの typecheck/lint/test と土台の自己検証がともに緑）
- SessionStart フックの警告が出ないこと
- 追加した自己検証やゲートは、`package.json`（`type:module` 含む）が存在する環境でも壊れないこと
  （ドッグフーディングの教訓。`docs/process/dogfooding.md`）
- 変更を Conventional Commits でコミットし、PR を作成する
