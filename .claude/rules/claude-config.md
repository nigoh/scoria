---
paths:
  - ".claude/**"
---

# steering 構成の編集規約

このリポジトリは「どの指示をどの機構に置くか」を意図的に使い分ける。設計判断は ADR-0001 参照。

## 機構の選び分け

- **CLAUDE.md（root）**: 常時必要な恒常的事実のみ（構成・コマンド・絶対原則）。**200行未満**を保つ。手順・チェックリストを置かない。
- **rules（`.claude/rules/`）**: 領域別の規約。frontmatter `paths:`（globリスト）でスコープし、該当ファイルに触れた時だけ注入する。無条件ロードにする場合は frontmatter を付けず、先頭に `<!-- unscoped -->` を明示する。
- **skills（`.claude/skills/<name>/SKILL.md`）**: 人が起動する手続き的ワークフロー。`name`/`description` 必須。重いスキルは `disable-model-invocation: true` でユーザー起動限定にする。本文は500行未満、補助資料は同フォルダに分け `${CLAUDE_SKILL_DIR}/...` で参照。`.claude/commands/` は使わない（skills に統合済み）。
- **agents（`.claude/agents/*.md`）**: 隔離・並行で走る役割。最小権限の `tools` を与える。監査系（reviewer/auditor）には Write/Edit を与えない。Bash を与える場合は読み取り用途に限る旨を本文に明記する。`model:` はエイリアス（`haiku`/`sonnet`/`opus`/`inherit`）のみ。番号付き固定IDを書かない。
- **workflows（`.claude/workflows/*.js`）**: 決定論的な多エージェント編成。冒頭に `export const meta = { name, description, phases }`（純リテラル）必須。素の JS のみ（TS 注釈不可）。`Date.now()`/`Math.random()`/引数なし `new Date()` は使用禁止（日付は args で渡す）。既存エージェントは `agentType` で再利用する。
- **hooks（`.claude/hooks/` + settings.json）**: 決定論的な強制のみに使う（exit 2 でブロック）。「ソフトな助言」を hooks にしない。ブロック時は必ず代替手段を stderr で案内する。

## 規律

- ルールは3層で守る: ドキュメント（助言）⇄ hooks（実行時ブロック）⇄ CI（機械検証）。強制したい規約は3層すべてに置く。
- 品質ゲートは `scripts/check.sh` が唯一の入口。フックや CI に個別ゲートを直書きしない。
- 構成を変更したら `bash scripts/validate-foundation.sh` で自己検証を通すこと（Stop フックでも自動実行される）。
- 監査系エージェント（reviewer/auditor）と実装系エージェント（implementer/engineer）の職掌をワークフロー内でも混ぜない。
- スキル・エージェントを増減したら CLAUDE.md の一覧表と同期する。
- frontmatter の `description` は「何をし、いつ使い、何を返すか」を1〜3文で書く（自動起動の精度がここで決まる）。

## エージェント報告形式の統一

- 指摘・結果は Markdown 表で返す。カラム: `#`, `重篤度`, `種別`, `場所（ファイル:行）`, `内容`
- 重篤度: ERROR > WARNING > INFO
- 読み取り専用エージェントは「推奨フォローアップ」で次に呼ぶべきエージェントを明記
- 実装エージェントは「残課題」で未完了項目を明記
