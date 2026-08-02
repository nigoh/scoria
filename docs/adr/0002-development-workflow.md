# 0002: 開発ワークフロー（ラウンド + GitHub Flow + Conventional Commits）

- Status: Accepted
- Date: 2026-07-17
- Deciders: リポジトリオーナー

## Context（背景）

Claude Code 主導の開発は反復が速い分、スコープクリープと学びの散逸が起きやすい。
反復の単位・ブランチ運用・コミット規約を最初に固定しておく必要がある。

## Decision（決定）

- 開発は「ラウンド」単位で回す。開始・振り返りは `/round` スキルを使う。
  ラウンドはトラッキングイシュー（`[round] Round N: テーマ`）で管理し、non-goals を必ず書く
- ブランチ運用は GitHub Flow: main へ直接コミット・プッシュしない。トピックブランチ + PR 経由
  （hooks / permissions.deny / ブランチ保護の3層でブロック）
- コミット件名・PR タイトルは Conventional Commits: `feat|fix|docs|test|refactor|chore|ci(scope): subject`
- 設計・技術・運用の決定は ADR に記録する（`/adr` スキル）
- 設計に分岐のある修正は `/fix` スキルで提案 → 選択 → 忠実実装。自明な修正は直接実装してよい
- ラウンドの学びは「気づきカード」イシュー → 規約（CLAUDE.md / rules / ADR）への反映、で資産化する

## Options Considered（検討した選択肢）

### 案1: ラウンド + GitHub Flow + Conventional Commits（採用）

- 長所: 反復単位が明確。振り返り→規約進化のループが回る。CI で機械検証できる
- 短所: 小さな変更にも一定の手続きコスト

### 案2: 自由運用（規約なし）

- 長所: 立ち上がりが速い
- 短所: AI 主導の高速反復では履歴と学びが散逸し、後から規約を入れるコストが高い

## Consequences（結果）

- すべての変更が PR 履歴と ADR で追跡できる
- **再検討のトリガー**: チーム人数や開発速度が変わり手続きが律速になったら、ゲートの粒度を見直す
