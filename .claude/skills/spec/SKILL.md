---
name: spec
description: >
  超上流の要件定義を行う。機能要件(REQ)・非機能要件(NFR)・受入基準・トレーサビリティ ID を
  固定様式で起こし、docs/requirements/ に成果物を作る。実装前の段階ゲート（ADR-0005/0006）。
disable-model-invocation: true
argument-hint: "[定義したい機能・システムの概要]"
---

# 要件定義（超上流）

実装前に要件を確定する段階ゲート。プロセス定義は `docs/process/requirements.md`、ID 体系は
`docs/process/traceability.md` に従う。テーラリング（軽い変更は省略可）は `lifecycle.md` の基準に従う。

## 1. スコープの確認

- `$ARGUMENTS` と会話から対象と背景を掴む。`/round` でスコープ合意済みならそれを起点にする
- 既存の `docs/requirements/` を読み、追記か新規かを判断する

## 2. 機能要件（REQ）

- `docs/process/templates/requirement-spec.md` を雛形に `docs/requirements/<領域>.md` を作る
- 各機能要件を `REQ-<領域>-<3桁>` で採番（既存の最大連番+1）
- 各 REQ に「ユーザーストーリー」＋「受入基準（Given/When/Then など検証可能な形）」を書く
- 優先度（要求品質の優先順位付け、IPA 5章）を付ける

## 3. 非機能要件（NFR）— カテゴリを必ず一巡

`docs/process/requirements.md` の7カテゴリ（性能・信頼性・使用性・セキュリティ・保守性・移植性・運用性）を
**必ず一巡**し、各カテゴリについて `NFR-<分類>-<3桁>` を起こすか「対象外」と明記する（検討漏れと区別）。
各 NFR に測定可能な受入基準（閾値＋根拠）を書く。

## 4. 役割・重要度・合意

- 各要件に責任者（要求元・実装責任・検証責任）を記録する
- 対象コンポーネントの**重要度（システムプロファイル: 高/中/低）**を識別する（`lifecycle.md` 軸1）。
  高影響領域（認証・決済・個人情報等）は後続のテーラリングでゲートが引き上がる
- 変更管理ルール（`requirements.md`）を確認し、合意をイシュー／PR に記録する

## 5. 段階ゲートの確認

`docs/process/requirements.md` のチェックリストを満たすか確認する:
全 REQ に受入基準／NFR 一巡／責任者記録／合意記録。仕上げに `bash scripts/check.sh`
（`check-traceability.sh` が受入基準の存在を検査）を通す。

> 要件を確定したら、対応するテスト（TEST）は `/test-design` で設計し、`Verifies: REQ-...` で結ぶ。
