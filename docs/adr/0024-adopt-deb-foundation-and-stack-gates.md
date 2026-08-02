# 0024: deb の開発土台を移植し、Vite + React スタックを品質ゲートに配線する

- Status: Accepted
- Date: 2026-08-02
- Deciders: リポジトリオーナー

## Context（背景）

Scoria は Vite + React + TypeScript のアプリとして先に実装が進み、開発の進め方を支える仕組みが
無いまま育っていた。移植前の実態は次のとおり。

- 品質ゲートが存在しない。`typecheck` / `lint` / `test` は npm script として在るが、実行を強制する
  機構（フック・CI）が無い。`.github/` 自体が無く CI が1本も動いていない
- `npm run format:check` が 43 ファイルで落ちる状態が放置されていた（誰も走らせていなかった証拠）
- テストは `src/lib/generator.test.ts` の 15 件のみ。`templates.ts`（1132行）・`constants.ts`・
  `cli.ts`・`zip.ts`・stores 3本は無テスト
- `.claude/` は `settings.json`（プラグイン有効化のみ）と `test-runner` エージェント1体だけ。
  規約・スキル・フックが無く、Claude Code に渡る恒常情報は乖離した CLAUDE.md しか無い

一方、同じオーナーの `nigoh/deb` は「Claude Code で開発するときの進め方とルール一式」を持つ土台
リポジトリで、単一入口の品質ゲート（`scripts/check.sh`）・steering・V字プロセス・ADR 運用が揃っている。
deb は本来 "Use this template" で複製して使う設計（ADR-0003）だが、Scoria は既存リポジトリなので
複製経路が使えない。土台をどう取り込むかを決める必要がある。

## Decision（決定）

**deb の土台を Scoria へ手で移植し、Scoria のスタックを `scripts/check.sh` に配線する。**

- **移植するもの**: `.claude/`（rules / skills / agents / workflows / hooks / settings）・
  `scripts/`（品質ゲートと自己検証一式）・`tools/shdoc`・`docs/adr`・`docs/process`・`.github/`（CI と
  テンプレート）・`mape/`・`knowledge/`・`CONTRIBUTING.md`・`LICENSE`
- **ADR は 0001〜0023 をそのまま引き継ぐ**。steering 本文が ADR 番号を相互参照しているため、
  番号を振り直すと参照が全部切れる。Scoria 固有の決定は 0024 から採番する
- **スタックの配線**: `scripts/check.sh` の「スタック固有のゲート」節に `npm run typecheck` /
  `npm run lint` / `npm run format:check` / `npm test` を追記する。check.sh は Stop フックと CI の
  共通入口なので、この1箇所でローカルと CI の両方に効く（ADR-0004）
- **CI**: `checks.yml` に `actions/setup-node` と `npm ci` を足す。gawk と同じく「ゲートを動かすための
  道具立て」であり、検査の実体は check.sh 側に置いたままにする

## Options Considered（検討した選択肢）

### 案1: 土台を丸ごと手で移植する（採用）

- 長所: rules・CI・`check.sh`・プロセス定義・ADR 運用がすべて効く。機械強制が最も強い
- 短所: deb 固有の前提（→ ADR-0025）を個別に潰す必要がある。取り込み後は deb 本体の更新が
  自動では降ってこない（手で追随する）

### 案2: コンパニオンプラグイン `deb-steering` を入れるだけ

- 長所: `.claude/settings.json` に数行足すだけ。deb 側の更新に自動追随する
- 短所: プラグインでは rules（`paths:` スコープ）・root CLAUDE.md・CI・`scripts/check.sh` を配れない
  （ADR-0008）。「進め方の助言」は入るが機械強制はほぼ効かない。Scoria の課題（ゲートが無い・
  CI が無い・整形が壊れている）はどれも解決しない

### 案3: 移植せず、必要なゲートだけ自前で書く

- 長所: 持ち込む量が最小
- 短所: 単一入口・fail-closed・トレーサビリティといった設計判断を一から作り直すことになる。
  deb 側で既に検証済みの資産を捨てる

## Consequences（結果）

- Stop フックが未コミット変更のたびに `scripts/check.sh` を走らせるため、整形崩れや型エラーを
  抱えたままターンを終えられなくなる
- テスト空白（`templates.ts` 等）はゲートに載っただけでは埋まらない。網羅率の定量ゲートは
  テスト実装後に check.sh へ追加する（`docs/process/verification.md`）
- deb 本体の steering が更新されても自動では届かない。取り込みたい変更は差分を見て手で移植する
- **再検討のトリガー**: プラグインで rules や CI を配布できるようになったら、移植ではなく
  プラグイン購読へ切り替えられるか見直す
