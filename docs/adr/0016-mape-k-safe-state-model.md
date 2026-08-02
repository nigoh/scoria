# 0016: MAPE-K の安全状態（safe-state）モデル — fail-safe 断片を安全性の第一級モデルへ集約

- Status: Proposed
- Date: 2026-07-22
- Deciders: （PR レビュアー）

## Context（背景）

MAPE-K（ADR-0010/0011）は無人で PR を開く自律ループを持つ。安全機構は既に複数あるが、
**散在した断片**として存在し「安全性（Safety, ISO/IEC 25010:2023 の9特性目）」という
第一級の観点として体系化されていない（`knowledge/PERSPECTIVES.md` の Safety 項が穴として明示）:

- circuit-breaker（連鎖失敗で停止。ADR-0015 で項目隔離・有界回復も追加）
- 赤→破棄（Execute はテスト赤なら変更を捨てる。REQ-MAPE-004）
- 1周1件（暴走面積の制限。POLICY 運用モード）
- consult 除外（認証/課金/データ/秘密/デプロイは無人実行しない。NFR-SEC-001）
- main/秘密/ロックファイルへ触れない（CLAUDE.md 絶対原則・guard-* hooks）

ADR-0014 は「safe-state 未定義」を自己修復の欠落として挙げ、ロードマップに safe-state の定義を置いた。
制約: ADR-0003（スタック非依存）/ ADR-0004（ゲート単一入口・弱めない）/ ADR-0013（test-first）。
既存の安全境界は**弱めない・追加のみ**。ADR-0010/0011/0014/0015 を延長する。

## Decision（決定）

MAPE-K に「**安全状態（safe-state）**」を第一級モデルとして定義する。安全状態とは、無人 Execute を
行ってよい**不変条件の連言**であり、決定論スクリプト `mape/safe-state.sh` が判定して
`MAPE_SAFE=0|1` を出力する。**不変条件**（すべて真のとき MAPE_SAFE=1）:

1. **保護ブランチ上でない**（`main|master` 以外のトピックブランチ）
2. **knowledge/ 整合性が green**（`mape_verify_knowledge`。細胞の DNA が壊れていない）
3. **作業ツリーがクリーン**（未コミット変更に無人 Execute を重ねない）
4. **サーキットブレーカーが既知かつ非 tripped**

**entry（安全側）**: 上記4条件が満たされたとき。判定は read-only・非破壊。
**exit（危険側＝MAPE_SAFE=0）**: いずれか1条件でも破れたとき、または判定に必要な情報が得られない
（git 不在・detached HEAD・`mape_verify_knowledge` 未定義など）とき＝**フェイルセーフ**（guard-* と同じ安全側）。

MAPE_SAFE=0 の効果は**縮退（Execute の抑止）のみ**で、既存の tier 分類や M→A→P の読み取りは変えない。
`mape/run.sh` は M→A→P の**前**に safe-state を評価し、(a) HEALTH の既存 `note` 列へ安全タグを畳み
（列は増やさない）、(b) MAPE_SAFE=0 のとき掲示本文（issue-body）と PROGRESS に Execute 抑止を明記する。
理由文字列は外部制御データ（ブランチ名）を含みうるため、下流へ流す前に既存の膜 `mape_sanitize_signal`
で無毒化する。本モデルは既存の各断片を**置換せず包含**する（circuit-breaker は不変条件4として組み込む）。

## Options Considered（検討した選択肢）

### 案1: 決定論スクリプト `mape/safe-state.sh` で不変条件を集約し MAPE_SAFE シグナルで Execute を抑止（採用）

- 長所: 既存の断片（circuit-breaker・赤→破棄・consult・guard）を壊さず1つの「安全状態」へ束ねる。
  read-only・追加のみで ADR-0003/0004/0013 に整合。test-first で回帰保護でき、情報欠落時も安全側。
  PERSPECTIVES の Safety の穴と ADR-0014 の safe-state 項に直接対応。
- 短所: Execute 自体は LLM スキル（/mape-execute）なので、機械強制はシグナル提示＋掲示注記まで。
  完全な機械ブロックにはスキル側の遵守が要る。

### 案2: 各断片を個別強化するに留め、統一モデルを作らない（不採用）

- 長所: 追加実装ゼロ。
- 短所: 「安全性」が観点として体系化されず穴が残る。新しい危険条件（DNA 破損・dirty tree）を漏らす。

### 案3: hooks/CI で Execute を機械ブロックする常時ゲートを新設（不採用）

- 長所: 機械強制力が最も強い。
- 短所: ゲートを単一入口 `scripts/check.sh` 以外に増設し ADR-0004 に反する。安全性判定は
  「今 Execute してよいか」の実行時状態であり、静的 CI ゲートとは性質が異なる（偽陽性で通常開発を阻害）。

## Consequences（結果）

- 得るもの: 危険時（main 上・DNA 破損・dirty tree・ブレーカー発火・情報欠落）に無人 Execute を
  安全側へ縮退させる単一の判定点。安全性が要件体系（NFR-SAFE-001/002）と ISO 25010:2023 に接続。
  既存断片の統一的な参照点（新しい危険条件は不変条件を1つ足すだけ）。
- 失うもの: フル機械ブロックではない（スキル遵守に依存する余地）。判定に薄いコスト（read-only で軽微）。
- **再検討のトリガー**:
  - フェイルセーフ（情報欠落→unsafe）が誤検知過多で通常運用を止めると判明したら、条件ごとの
    重み付け／unknown の扱いを新 ADR で見直す。
  - Execute スキルが MAPE_SAFE=0 を無視して実行した事例が出たら、機械ブロック（案3）の是非を再判断。
  - 不変条件の追加で偽陽性が増えたら、条件集合を POLICY で調律可能にする拡張を検討。
