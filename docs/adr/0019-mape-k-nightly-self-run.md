# 0019: MAPE-K の夜間自走（heartbeat）— GHA cron で決定論 M→A→P を毎晩実走する

- Status: Proposed
- Date: 2026-07-23
- Deciders: （PR レビュアー）

## Context（背景）

ADR-0014 は MAPE-K の**休眠**（HEALTH が cycle 2 で止まっている＝細胞が「生きていない」）を
核心的欠陥として挙げた。ADR-0011 は「毎晩1回 cron Routine で `/mape night` を起動する」と決めたが、
実際のスケジューラは配線されていない。効き目の実測（ADR-0020 予定）や set-point 自己調律（ADR-0021 予定）は
**HEALTH 時系列と台帳の蓄積**を前提にするため、まず「毎晩必ず1周回る」心拍が要る。

制約: 絶対原則（main 直接コミット禁止・無人はマージしない・トピックブランチ＋PR）。ADR-0004（ゲート単一
入口）。ADR-0011 の無人 Execute 安全境界（consult 除外・1周1件・緑のみドラフト PR・ブレーカー厳守）。
既知の制約（ADR-0011）: headless セッションでは GitHub 等の対話認証 MCP が使えないことがある。

## Decision（決定）

**GitHub Actions の cron で、毎晩 決定論 M→A→P（`bash mape/run.sh --record`）を実走する**
（`.github/workflows/mape-nightly.yml`）。これは細胞の**心拍**であり、**新しい自律性は一切足さない**
（既にゲート済み・読み取り専用の M→A→P 経路を「起動」するだけ）。

- **読み取り専用の M→A→P のみ**。壊しうる Execute（実装）はワークフローに含めない（GHA には LLM が無く、
  Execute は本質的に LLM スキル `/mape execute`）。
- 変更は `knowledge/`・`mape/state/` の**証跡に限定**。**必ずトピックブランチ**（`chore/mape-cycle-*`）へ
  コミットし、**ドラフト PR** で提出する（main 直接禁止・**無人マージ禁止**を機械的に守る）。ブランチ名が
  保護名（main/master）なら中止する多層防御。
- `permissions` は `contents: write` ＋ `pull-requests: write` のみ（列挙外は全て落ちる）。issues は使わない
  （計画イシューの掲示は対話セッションの `/mape night` が担う。headless-auth 制約の回避）。
- 変更が無い周回は**心拍のみ**（PR を作らない）。`concurrency` で多重起動を直列化。
- run.sh は先頭で safe-state を評価するが、GHA は Execute しないため影響は掲示注記のみ。休眠検知
  （`MAPE_STALE_MAX_H=36`）により、cron が死ねば次の対話周回で P1「ループ休眠」提案が自動で出る
  （スケジューラ障害の自己検知）。

任意の拡張（別レイヤ・運用）として、対話セッションが使える環境では cron Routine による
**safe-state 通過時のみ 1件のゲート付き Execute**（consult 除外・緑のみドラフト PR・無人マージ禁止）を
足してよい。これは本 ADR の GHA 心拍とは独立で、既存の無人 Execute 安全境界（ADR-0011）に従う。

## Options Considered（検討した選択肢）

### 案1: GHA cron で決定論 M→A→P（心拍）＋ 任意の Routine ゲート付き Execute（hybrid・採用）

- 長所: **LLM/対話認証に依存せず**毎晩必ず心拍が刻まれる（M→A→P は決定論）。証跡は必ずドラフト PR で
  レビュー可能・無人マージ無し。新しい自律性ゼロ（既存の安全な経路を起動するだけ）。Execute は追加・任意で
  全ゲート付き。ADR-0004（ゲート単一入口）と絶対原則に整合。
- 短所: 毎晩ドラフト PR が1本増える（HEALTH は毎周1行増えるため通常は必ず変更あり）。運用のノイズ。

### 案2: LLM Routine のみ（fresh session per fire）で M→A→P も Execute も回す（不採用）

- 長所: 掲示（issue 更新）と Execute を一気通貫でできる。
- 短所: headless セッションで GitHub 対話認証 MCP が使えないと掲示/Execute が劣化し、**心拍そのものが
  セッション可用性に依存**する。心拍の信頼性を最優先する本 ADR の目的に反する。

### 案3: 何もしない（現状維持）（不採用）

- 長所: 追加ゼロ。
- 短所: 休眠が続き（ADR-0014 の核心的欠陥）、効き目実測・自己調律の前提データが貯まらない。「生きた
  細胞」の本旨を満たさない。

## Consequences（結果）

- 得るもの: 毎晩の心拍で HEALTH 時系列が蓄積し休眠が解消。ADR-0020/0021 の前提データが揃う。証跡は
  必ずレビュー可能なドラフト PR。スケジューラ障害は休眠検知で自己申告。
- 失うもの: 夜間ドラフト PR のノイズ（毎晩1本）。GHA の実行コスト（軽微・M→A→P は数十秒）。
- **再検討のトリガー**:
  - 夜間ドラフト PR が多すぎて運用を圧迫 → 1本のローリング PR へ集約、または HEALTH 行だけを間引いて
    コミット頻度を下げる方式を新 ADR で検討。
  - GHA cron が不安定（skip/遅延多発） → 休眠検知が P1 を出し続けたら、外部 CI 以外のスケジューラ
    （専用 Runner・Routine）へ移行を再判断（ADR-0014 のスケジューラ根因のエスカレーション）。
  - headless GitHub 認証が安定して使えるようになった → 掲示/Execute を GHA 側へ寄せる集約を検討。
  - 夜間 Execute（Routine 版）が PR ノイズ/churn を生む → Execute の頻度を M→A→P より下げる、または
    承認数しきい値でゲートする。
