# 0025: コンパニオンプラグインを移植対象から外し、ドキュメント系ゲートを Scoria 向けに向け直す

- Status: Accepted
- Date: 2026-08-02
- Deciders: リポジトリオーナー

## Context（背景）

deb の土台を Scoria へ移植する（ADR-0024）にあたり、そのままでは成立しない前提が3つあった。

1. **`index.html` の意味が違う**。deb では GitHub Pages のランディングページ（文書）だが、
   Scoria では **Vite のエントリーポイント＝アプリの実体**。`check-docs-structure.sh` は
   `index.html` / `guide.html` / `reference.html` を文書として構造検査するので、移植すると
   アプリのマークアップをピラミッド原則で検査して必ず落ちる（偽失敗）
2. **`plugin/` は deb の同一性そのもの**。`plugin/` と `.claude-plugin/marketplace.json` は
   「deb の steering を他リポジトリへ配る」ための配布物（ADR-0008）。Scoria が同じものを持つと、
   `deb-marketplace` という同名マーケットプレイスが2つ存在するか、deb 由来の steering を
   Scoria 名義で再配布することになる
3. **`build-docs.sh` が deb にリンクしている**。生成される `reference.html` のナビ・フッタが
   `index.html` / `guide.html`（deb のランディングサイト）を指しており、Scoria には存在しない

## Decision（決定）

**ドキュメント系ゲートは対象を `docs/` 配下へ向け直し、コンパニオンプラグインは移植しない。**

- **`check-docs-structure.sh` の検査対象を `docs/reference.html` / `docs/guide.html` に限定する**。
  リポジトリ直下の `index.html` は文書ではないので対象外にする。この判断は
  `.claude/rules/docs.md` にも同じ言葉で書き、規約と検査を一致させる
- **`build-docs.sh` の出力先を `docs/reference.html` にする**。リポジトリ直下は Vite の領域なので
  生成物を置かない。リンク先リポジトリを `nigoh/scoria` に変え、存在しないページ
  （`index.html` / `guide.html`）へのナビリンクを外す。土台の出自はフッタの帰属表記に残す
- **`plugin/` ・ `.claude-plugin/` ・ `build-plugin.sh` ・ `test-build-plugin.sh` は移植しない**。
  対応する2行を `scripts/check.sh` から外す。`validate-foundation.sh` の §10 は
  `[ -d plugin ]` で自己スキップするため改変不要

## Options Considered（検討した選択肢）

### 案1: 対象を向け直し、プラグインは持ち込まない（採用）

- 長所: 偽失敗が起きない。Scoria が deb の配布物を二重に名乗らない。移植量が減る
- 短所: Scoria 独自の steering を将来プラグインとして配りたくなったら作り直しになる

### 案2: プラグインも移植し `scoria-steering` に改名する

- 長所: ADR-0024 の「丸ごと移植」に最も忠実
- 短所: 中身は deb の steering そのままなので、deb-steering の重複を Scoria 名義で配ることになる。
  Scoria はアプリであって steering 配布リポジトリではない

### 案3: ドキュメント系ゲート（build-docs / check-docs-structure）ごと落とす

- 長所: 適合作業が不要
- 短所: 移植したシェル機構（check.sh・hooks・mape）のリファレンスと文書規約を捨てることになる。
  ADR-0021 / 0022 で得た「注釈とドキュメントの乖離を機械で防ぐ」性質が失われる

## Consequences（結果）

- `docs/reference.html` が移植したシェルスクリプトのリファレンスとして生成・検査される
- Scoria の steering を外部へ配る導線は無い。必要になったら本 ADR を supersede して作る
- **再検討のトリガー**: Scoria が独自のスキル・エージェントを持ち、他リポジトリへ配りたくなったとき
