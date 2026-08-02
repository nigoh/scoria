---
name: orchestrate
description: >
  .claude/workflows/ の名前付きワークフロー（understand / bug-hunt / quality-gates）を Workflow ツールで
  決定論的に実行する。「オーケストレーションして」「徹底的に調べて」「並列で監査して」と明示されたときに使う。
  構造化された結果（確定バグ・監査所見・統合回答）を要約して返す。
disable-model-invocation: true
argument-hint: "[understand|bug-hunt|quality-gates] [対象や質問]"
---

# 決定論的オーケストレーション

多エージェント編成は大量のトークンを使う。**ユーザーの明示要求があるときだけ**起動する。

## ワークフローの使い分け

| ワークフロー | 用途 | args |
|---|---|---|
| `understand` | 領域横断の並列調査 → 統合回答 | `{ "question": "...", "targets": ["dir", ...] }` |
| `bug-hunt` | 観点別レンズで並列バグ発見 → 敵対的検証 → 確定バグのみ返す | `{ "scope": "対象範囲" }` |
| `quality-gates` | PR 前の品質ゲート並列実行（reviewer / doc-auditor / rule-auditor / process-auditor + check.sh） | `{ "base": "main" }` |

## 実行手順

1. 対象ワークフローの `.claude/workflows/<name>.js` を確認する
2. `Workflow({ scriptPath: ".claude/workflows/<name>.js", args: {...} })` で実行する。
   args がスクリプトに届かない環境では、スクリプトを読んで定数を埋めた**インライン script** で実行する（各スクリプトの parseArgs は文字列/オブジェクト両対応の防御的実装になっている）
3. 結果の構造化データ（confirmed / findings / answer）を人間が読める形に要約して報告する

## サイクル運用（枯れるまで）

- bug-hunt は「確定バグ 0 件」になるまで 発見→修正→再実行 を繰り返せる（修正はメインループまたは implementer で**直列に**行う。並列エージェントに書き込みさせない）
- 停止条件を必ず決めてから回す（確定 0 件 / N ラウンド上限 / 予算上限）
