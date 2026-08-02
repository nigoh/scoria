# CONTRIBUTING

開発手順・規約の一次情報。Claude Code 向けの恒常事実は CLAUDE.md、機構配置の規約は ADR-0001 を参照。

## ブランチ運用（GitHub Flow）

- main へ直接コミット・プッシュしない（hooks / permissions / ブランチ保護でブロック）
- トピックブランチ名: `claude/<topic>`（Claude 作業）または `feat/<topic>` 等
- force push 禁止。履歴の書き換えが必要な場合は人間が明示的に行う

## コミット / PR

- コミット件名・PR タイトルは Conventional Commits（英語）:
  `feat|fix|docs|test|refactor|chore|ci(scope): subject`（破壊的変更は `feat(scope)!: subject` のように `!` を付ける）
- PR 本文: 「変更内容」「テスト」セクション必須。関連イシュー番号を書く
- PR はドラフトで作成し、CI 緑 + レビューを経てマージする
- テストなしの feat PR は禁止（土台のみの変更は validate-foundation.sh が代替ゲート）
- 純粋ロジック・重要度高の実装は test-first（赤を観測→緑→refactor）を標準リズムとする（ADR-0013 / `.claude/rules/tdd.md`）

## 品質ゲート

- 唯一の入口は `bash scripts/check.sh`。ローカル（Stop フック）と CI が同じものを実行する
- 中身は「土台の自己検証」＋「スタック固有ゲート」（`typecheck` / `lint` / `format:check` / `test`。ADR-0024）
- ゲートを追加・変更するときは check.sh / validate-foundation.sh を編集する（ADR-0004）
- ゲートの実行には Node.js と `gawk` が要る（`npm ci` 済みであること。CI は checks.yml で両方用意する）

## 意思決定

- 設計・技術選定・運用の決定は ADR に記録する（`/adr` で作成、規約は `.claude/rules/adr.md`）
- 3ファイル以上に影響する構成変更・破壊的変更は先に ADR を書く

## ラウンド運用

- 開発は「ラウンド」単位（ADR-0002）。`/round` で開始・振り返りを行う
- 発見したパターン・仮説は「気づきカード」イシュー（`insight-card` ラベル）として起票する
- 振り返りで得た学びは CLAUDE.md / rules / ADR への PR として反映する

## イシュー

- バグ報告: 再現手順（番号付き）・期待/実際の動作・重篤度が必須
- 機能要求: ユーザーストーリー形式・ADR 要否の判断が必須
- テンプレートは `.github/ISSUE_TEMPLATE/` を使う
- 使用ラベル: `bug` / `enhancement` / `insight-card`（気づきカード）/ `round`（ラウンド追跡）/
  `template-feedback`（テンプレート由来リポジトリからの土台改善提案。ADR-0009）。
  リポジトリに未作成のラベルは初回使用時に作成する

## フィードバック（テンプレート由来リポジトリから本家へ）

deb をテンプレート/プラグインとして使って気づいた土台への改善は、`/feedback` スキル、または本家の
`template-feedback` イシューテンプレートで本家 `nigoh/deb` に送る（ADR-0009）。アプリ固有・秘密情報は含めない。
