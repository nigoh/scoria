# mape/ — MAPE-K 夜間セルフ改善（決定論スクリプト）

「安く読んで考える」M/A/P を決定論の Bash として実装したもの（ADR-0010）。
夜間周回（M→A→P）と「壊しうる」Execute はともに Claude 起動スキル `/mape`（`/mape night` / `/mape execute`）。
共有ナレッジ（K）は `../knowledge/`。

## スクリプト

| ファイル | フェーズ | 役割 |
|---|---|---|
| `monitor.sh` | M | シグナル収集 → `state/monitor.env`・`monitor.md`（`--record` で HEALTH.md 追記） |
| `analyze.sh` | A | 症状化＋根拠つき提案（スコア順）→ `state/proposals.tsv`・`analysis.md`（`--update-knowledge` で BACKLOG 追記） |
| `plan.sh` | P | リスク3分類チェックリスト → `state/issue-body.md` |
| `run.sh` | M→A→P | 上記を1周まわす統合ランナー（`--record` で knowledge も更新。A の前に効き目を更新し safe-state を評価） |
| `efficacy.sh` | K→A | 委託台帳から重点テーマ別の効き目（`state/efficacy.tsv`）を学習し Analyze の採点へ還元（ADR-0017） |
| `circuit-breaker.sh` | ガードレール | 実行台帳（`state/ledger.jsonl`）と連鎖失敗の停止判定・冪等性クエリ・項目隔離（ADR-0015） |
| `safe-state.sh` | ガードレール | 安全状態の不変条件を判定し危険時は `MAPE_SAFE=0` で無人 Execute を抑止（ADR-0016） |
| `lib.sh` | 共通 | ルート解決・分類・却下判定・スコア・恒常性/効き目/トレンド/隔離（source 用） |
| `tests/run.sh` | 検証 | 決定論部分の自己テスト（`scripts/check.sh` から実行） |

## 使い方

```bash
bash mape/run.sh            # ドライラン（state/ にだけ出力。knowledge は触らない）
bash mape/run.sh --record   # 本番の夜間周回（HEALTH/BACKLOG/PROGRESS も更新）

bash mape/circuit-breaker.sh status          # 実行可否（tripped なら exit 3）
bash mape/circuit-breaker.sh done "<項目>"   # 実装済み(green)なら exit 0（冪等性）
```

## 設計の約束

- スクリプトは既定で**読み取り専用**（書き込みは `state/` のみ）。`knowledge/` を変えるのはフラグ指定時だけ。
- `$MAPE_STATE_DIR` を差し替えれば隔離実行できる（テストは一時ディレクトリを使う）。
- リスク分類・却下ログ・閾値は `knowledge/POLICY.md` と `lib.sh` の環境変数で調整する。
- 本サブシステムは `mape/` と `knowledge/` に依存するため、コンパニオンプラグイン（ADR-0008）には含めない。
