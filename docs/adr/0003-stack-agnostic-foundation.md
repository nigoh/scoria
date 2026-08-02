# 0003: 土台はスタック非依存とし、スタック導入は /stack-init で行う

- Status: Accepted
- Date: 2026-07-17
- Deciders: リポジトリオーナー

## Context（背景）

deb は複数のアプリ開発の出発点になる土台リポジトリである。参照リポジトリの調査から、
steering 資産にドメインやスタックが結合していると再利用時に剥がすコストが高いことが分かっている。

## Decision（決定）

- 土台には特定言語・フレームワークを入れない。steering（.claude/）、品質ゲートの骨格（scripts/check.sh）、
  開発規約（docs/adr, CONTRIBUTING）のみを置く
- スタック導入は `/stack-init` スキルで行う: 選定を ADR 化し、check.sh に typecheck/lint/test を配線し、
  領域別 rules と CLAUDE.md を更新する
- 品質ゲートの入口は `scripts/check.sh` に一本化する。Stop フックと CI は check.sh を呼ぶだけにする

## Options Considered（検討した選択肢）

### 案1: スタック非依存の骨格 + /stack-init（採用）

- 長所: どのアプリにも使える。steering 資産が汚染されない。ゲート配線が1箇所で済む
- 短所: 開発開始時に初期化の一手間がある

### 案2: 最新の TypeScript スタックを同梱

- 長所: クローン直後から書き始められる
- 短所: 他言語のアプリで丸ごと剥がすことになる。バージョン腐敗の保守コストを土台が負う

## Consequences（結果）

- 土台自体の品質ゲートは steering の自己検証（validate-foundation.sh）になる
- **再検討のトリガー**: 作るアプリが単一スタックに収斂したら、テンプレートとして同梱する案を再検討する
