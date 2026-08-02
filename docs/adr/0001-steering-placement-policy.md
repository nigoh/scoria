# 0001: Claude Code steering の機構配置ポリシー

- Status: Accepted
- Date: 2026-07-17
- Deciders: リポジトリオーナー

## Context（背景）

Claude Code には指示を置く機構が複数ある（CLAUDE.md / rules / skills / agents / workflows / hooks / settings）。
配置基準がないと CLAUDE.md が肥大化し、常時ロードのコンテキストコストが増え、強制すべき規約が「お願い」のまま破られる。

## Decision（決定）

読み込みコストと強制力で機構を使い分ける:

| 機構 | 読み込み | 用途 |
|---|---|---|
| CLAUDE.md | 常時（高コスト） | 恒常的事実のみ。200行未満 |
| rules（`paths:` スコープ） | 該当ファイルに触れた時 | 領域別の規約 |
| skills | `/name` 起動時 | 手続き・チェックリスト |
| agents | 委譲時（隔離コンテキスト） | 並行・隔離すべき役割。最小権限 |
| workflows | 明示要求時 | 決定論的な多エージェント編成 |
| hooks | イベント時（コンテキスト外） | 決定論的な強制。exit 2 でブロック |

強制したい規約は「ドキュメント（助言）・hooks（実行時ブロック）・CI（機械検証）」の3層すべてに置く。
詳細な編集規約は `.claude/rules/claude-config.md` に置き、`scripts/validate-foundation.sh` で機械検証する。

## Options Considered（検討した選択肢）

### 案1: 読み込みコスト×強制力による配置マップ（採用）

- 長所: コンテキスト消費が最小で強制が確実。参照リポジトリ（Idz/holonet/Juml/do_hug）で実証済み
- 短所: 機構が多く学習コストがある（→ .claude/README.md で導線を用意）

### 案2: CLAUDE.md にすべて集約

- 長所: 1ファイルで見通せる
- 短所: 常時ロードで高コスト。強制力がなく、行数が増えるほど遵守率が下がる

## Consequences（結果）

- CLAUDE.md は 200 行未満に保たれ、validate-foundation.sh が検証する
- 規約追加時は「どの層に置くか」を必ず判断することになる
- **再検討のトリガー**: Claude Code の機構体系が大きく変わったら（例: rules/skills の統合）見直す
