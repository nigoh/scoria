# 0008: 移植可能サブセットを deb 内のコンパニオンプラグインとして提供する

- Status: Accepted
- Date: 2026-07-18
- Deciders: リポジトリオーナー

## Context（背景）

deb は「テンプレート複製」で使うのが主（ADR-0003）。CI・hooks・`scripts/check.sh`・`docs/process`・
ADR はリポジトリ常駐で初めて機能するためである。一方、**既存の（deb テンプレート由来でない）リポジトリ**へ
deb の働き方（skills/agents/guard hooks）だけを持ち出したい需要がある。Claude Code のプラグイン機構は
skills/agents/hooks を配布できるが、rules（`paths:` スコープ）・root CLAUDE.md・CI・プロジェクトの
`scripts/` は配布できない。この非対称性をどう扱うかを決める。

## Decision（決定）

**移植可能サブセットを deb リポジトリ内のコンパニオンプラグイン（`plugin/`）として提供する。**

- **配布物（プラグインに含める）**: skills（`/fix` `/round` `/adr` `/spec` `/test-design` `/postmortem`）、
  agents 8体、guard hooks（`guard-git` `guard-protected`）。
- **含めない（テンプレート複製が必要）**: `.claude/rules/*.md`、root `CLAUDE.md`、CI、`scripts/check.sh` 等の
  品質ゲート実体、`docs/process`・`docs/adr` 雛形、`/orchestrate` と `.claude/workflows/`。
  → プラグインは「メソドロジーの持ち出し」であり、機械強制は薄まる。
- **単一の正本 = `.claude/`**: `plugin/` の skills/agents/hooks は `scripts/build-plugin.sh` が `.claude/` から
  生成する。手編集しない。**乖離は `build-plugin.sh --check` が検出**し `scripts/check.sh` に配線する
  （do_hug 由来の「4箇所同期」規律と同じく、ドリフトを機械で防ぐ）。
- **配布形態**: リポジトリルート `.claude-plugin/marketplace.json` がプラグイン（`./plugin`）を提供する。
  導入は `/plugin marketplace add nigoh/deb` → `/plugin install deb-steering@deb-marketplace`。

## Options Considered（検討した選択肢）

### 案1: deb 内のプラグイン + 生成による同期ガード（採用）

- 長所: 単一リポジトリで保守。正本が1つ（`.claude/`）でドリフトを機械検出。テンプレートと一貫
- 短所: プラグインとテンプレートで同じ steering が二重に存在する（→ 生成＋--check で乖離を防ぐ）

### 案2: 別リポジトリに切り出す

- 長所: 関心の分離が明確
- 短所: 新規リポジトリとクロスリポジトリ保守が発生。正本の二重管理でドリフトしやすい

### 案3: プラグイン化しない（テンプレートのみ）

- 長所: 最も単純
- 短所: 既存リポジトリへ steering を持ち出す導線が無い

## Consequences（結果）

- `plugin/` は生成物。編集は `.claude/` 側で行い `bash scripts/build-plugin.sh` で再生成する
- プラグインの限界（機械強制が薄い）は `plugin/README.md` に明示し、フル機能はテンプレート複製へ誘導する
- **再検討のトリガー**: プラグインで配布できる範囲が広がったら（例: rules 配布対応）、含める範囲を見直す
