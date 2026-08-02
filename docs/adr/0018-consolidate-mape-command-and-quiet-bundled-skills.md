# 0018: MAPE-K スキルを単一 `/mape` に統合し、`/` コマンド面を絞る

- Status: Proposed
- Date: 2026-07-23
- Deciders: （PR レビュアー）

## Context（背景）

deb は 11 個のユーザースキルを持ち、`/` コマンド補完の面が広い。Claude Code には
**プロジェクトスコープでスキルを個別に非表示にする allowlist が存在しない**（`disable-model-invocation`
は自律起動の抑止であって `/` メニュー可視性には効かない。公式 settings ドキュメントで確認）。
よって `/` 面を減らす確実なレバーは (a) deb 自身のスキルの統廃合、(b) 同梱スキルの一括非表示
（`disableBundledSkills`）の2つに限られる。

MAPE-K は `mape-night`（M→A→P・読み取り専用の掲示）と `mape-execute`（承認項目を1周1件実装）の
2スキルに分かれている。両者は単一サブシステム（`mape/`＋`knowledge/`）・単一 ADR 系譜
（0010/0011/0014/0015/0016/0017）・逐次ライフサイクル（night が板を作り execute が消化）を共有し、
利用者は「MAPE-K」を一つの機能として認識する。安全分割（night=読み取り専用 / execute=赤→破棄・
consult 除外・無人はマージ禁止・ブレーカー厳守）は本来スキル本文の関心事であり、ディレクトリを2つに
割る必然性はない。制約: マージ済み ADR（0010/0011/0015/0016）は編集不可（guard-protected）。

## Decision（決定）

**(1) `mape-night` と `mape-execute` を単一スキル `/mape` に統合**し、サブコマンドで分岐する:
`/mape night`（M→A→P）と `/mape execute`（Execute）。安全境界は本文内の2つの明確な節として
**不変のまま保持**する（night=読み取り専用 / execute=1周1件・トピックブランチ＋PR・緑のみ PR・
consult 除外・無人はマージ禁止・サーキットブレーカー厳守）。引数が曖昧なときはどちらを実行するか
ユーザーに確認する（破壊的な execute を勝手に走らせない）。

**(2) `.claude/settings.json` に `disableBundledSkills: true` を追加**し、同梱スキル（canvas-design/
docx/pdf/pptx/xlsx/dataviz/skill-creator 等・約15件）を `/` メニューとモデル提案から隠す。deb は
スタック非依存の開発土台であり、`/` は deb 自製の開発プロセス系スキルだけに絞るのが本旨。内蔵コマンド
（`/init` 等）は打てるが隠れる。**`disableWorkflows` は入れない**（多エージェント Workflow 機能を殺すため）。

マージ済み ADR に残る旧名 `mape-night`/`mape-execute` は不変ゆえ編集しない。歴史的記述として保持し、
本 ADR をもって「旧名（コマンド名・`.claude/skills/mape-*` パス）は現行の `/mape night` /
`/mape execute` サブコマンドおよび `.claude/skills/mape` を指す」と読み替える。

## Options Considered（検討した選択肢）

### 案1: `/mape` へ統合（サブコマンド night/execute）＋ `disableBundledSkills`（採用）

- 長所: `/` の deb 自製面を 11→10 に、同梱面を約15→0 に削減し「だいぶんシンプル」を実現。単一サブ
  システムを単一コマンドに一致させ発見性・メンタルモデルが単純化。安全分割は本文の節として保持でき、
  機械検証（check-skill-sync は dir=`mape` と表 `/mape` の一致で自動追従）も無改修。plugin 生成は
  mape を含まないため無影響。`disableBundledSkills` は check.sh 機構に依存が無く安全。1行で撤回可能。
- 短所: 1コマンドの責務が広がる。旧名参照（マージ済み ADR・cron Routine のプロンプト）に読み替え/
  更新が要る。同梱スキル（pdf/docx/xlsx 等）が使えなくなる（＝土台の意図に沿うが機能は失う）。

### 案2: 2スキルのまま維持し、面も絞らない（不採用）

- 長所: 変更ゼロ。night/execute の安全分割がディレクトリ境界として物理的に明白。
- 短所: `/` 面が減らず、簡素化の目的を満たさない。単一機能が2エントリに割れ選択コストが残る。

### 案3: spec/test-design 等も `/round` に畳んで更に統合（不採用）

- 長所: 面をさらに削減しうる。
- 短所: それらは独立した V字ゲート（ADR-0005）で専用エージェントを持ち、畳むと実装前ゲートの発見性と
  プロセス段階の分離が壊れる。安全/明快さの損失が面削減の便益を上回る。「単一サブシステム＝単一
  コマンド」の自然さも無い。

## Consequences（結果）

- 得るもの: `/` が deb の開発プロセス系スキルだけになり、体感が大きく簡素化。MAPE の入口が1つに揃い、
  今後の MAPE-K 深化（効き目実測・恒常性自己調律・nightly 自走）の土台も綺麗になる。
- 失うもの: 同梱スキル（pdf/docx/xlsx/pptx/dataviz 等）が既定で `/` から消える（`.claude/settings.json`
  の1行を消せば復活）。`/mape` 本文が長くなる（約185行、500行ゲート内）。
- 同期: CLAUDE.md スキル表・mape/README.md・knowledge/PROGRESS.md の前方参照を新名に更新。
  check-skill-sync / validate-foundation / build-plugin は動的または mape 非対象のため追加改修不要。
- 運用: 既存の夜間 cron Routine のプロンプトは `/mape night` / `/mape execute` へ更新する
  （リポジトリ外・運用作業）。
- **再評価トリガー**:
  - `/mape` 本文が肥大化し 500 行ゲートに近づく、または night/execute の安全境界が本文で曖昧になった
    → 再分割を検討（案2 へ差し戻し）。
  - Claude Code にプロジェクトスコープの skill allowlist（個別非表示）が追加された → 統合ではなく
    可視性制御で面を絞る方針へ再評価。
  - `disableBundledSkills` で失う同梱スキルが実運用で頻繁に必要と分かった → 設定を撤回、または
    Claude Code 側の個別許可機構が出たらそれに移行。
  - サブコマンド分岐が誤起動（night 意図で execute 実行等）を生んだ → 分岐 UX を見直すか再分割。
