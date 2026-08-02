#!/usr/bin/env bash
# @file .claude/hooks/session-start.sh
# @brief SessionStart hook: セッション開始時に現在地を要約して additionalContext として渡す。
# @description
#   常に exit 0（情報提供のみ。ブロックしない）。
#
#   出力する現在地: ブランチ名（detached HEAD なら短 SHA）・未コミット変更（先頭10件）・
#   直近3件の ADR・品質ゲート（scripts/check.sh）の有無。
#   これは「ソフトな助言」なので hooks の強制（exit 2）は一切行わない（.claude/rules/claude-config.md）。
#
# @stdin SessionStart フックの JSON（読まない。判定に使う入力が無いため）
# @stdout Markdown の要約（そのまま additionalContext としてセッションに注入される）
# @exitcode 0 常に（git 不在・リポジトリ外でも、cd 失敗でもブロックしない）
set -u

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

echo "## セッション開始時の状態"

# ブランチと変更状態
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # detached HEAD では --show-current が「空＋exit 0」を返すため || が効かない。空なら短SHAを出す。
  branch=$(git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch="(detached: $(git rev-parse --short HEAD 2>/dev/null || echo '?'))"
  echo "- ブランチ: ${branch}"
  changes=$(git status --porcelain 2>/dev/null | head -10)
  if [ -n "$changes" ]; then
    echo "- 未コミット変更あり:"
    echo "$changes" | sed 's/^/    /'
  else
    echo "- 作業ツリーはクリーン"
  fi
fi

# 直近の ADR（意思決定の文脈）
if ls docs/adr/[0-9]*.md >/dev/null 2>&1; then
  echo "- 直近のADR:"
  ls docs/adr/[0-9]*.md | sort | tail -3 | sed 's/^/    /'
fi

# 品質ゲートの案内
if [ -x scripts/check.sh ]; then
  echo "- 品質ゲート: scripts/check.sh（Stop フックと CI が同じものを実行）"
else
  echo "- 警告: scripts/check.sh が無い/実行不可。品質ゲートが機能しない"
fi

exit 0
