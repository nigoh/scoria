---
name: adr
description: >
  新しい ADR（意思決定記録）を正しい連番・テンプレートで作成する。アーキテクチャ・技術選定・
  開発プロセスの決定を記録するときに使う。docs/adr/ に NNNN-kebab-case.md を作り index を更新して返す。
argument-hint: "[決定の概要]"
---

# ADR 作成手順

1. **番号**: `docs/adr/[0-9]*.md` を Glob して最大番号 +1（4桁ゼロ埋め）を採番する
2. **ファイル**: `docs/adr/template.md` をコピーして `docs/adr/NNNN-kebab-case-title.md` を作成する
3. **記入**:
   - Status は `Proposed`（Accepted にするのは PR レビュー後、人間の指示による）
   - Context: 決定が必要になった背景・制約
   - Decision: 断定形で書く（「〜する」）
   - Options Considered: **必ず2つ以上**の選択肢を pros/cons 付きで
   - Consequences: 決定の帰結と、**再検討のトリガー条件**（「〜になったら見直す」）
4. **supersede**: 既存の決定を覆す場合、旧 ADR の本文は書き換えず Status 行のみ `Superseded by NNNN` に更新する
5. **index**: `docs/adr/README.md` の一覧に追記する（validate-foundation.sh が同期を検証する）
6. 関連するドキュメント（CLAUDE.md / CONTRIBUTING 等）から ADR 番号で参照させる

`$ARGUMENTS` が空なら、直近の会話から決定内容を要約して提案し、確認を取ってから書く。
