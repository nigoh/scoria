#!/usr/bin/env bash
# @file .claude/hooks/quality-gate.sh
# @brief Stop hook: ターン終了前の品質ゲート。
# @description
#   未コミット変更があるとき scripts/check.sh を実行し、
#   失敗したら exit 2 でターン終了をブロックする（＝「壊れたまま作業を終えない」）。
#
#   - CI と同じ入口 (scripts/check.sh) を呼ぶ。ゲートを増やすときは check.sh 側に足す
#   - 変更状態の SHA-1 で合格をキャッシュし、無変更なら再実行しない
#   - stop_hook_active=true（前回もこのフックが失敗）なら警告のみに降格し、無限ループを防ぐ
#
#   キャッシュの安全弁: state_hash が空（sha1sum 不在など）ならキャッシュを読み書きしない。
#   空のまま使うと「常に前回と一致」＝ゲートが恒久的に無効化されるため、必ず実行側へ倒す。
#   実行ビットの有無では check.sh の存在判定をしない（`bash scripts/check.sh` で呼ぶため
#   実行ビットは不要で、mode が落ちた環境でゲートが黙って無効化されるのを防ぐ）。
#
# @stdin Stop フックの JSON。`stop_hook_active` が true かどうかだけを見る（分岐前に必ず読み切る）
# @stderr 失敗時のブロック理由と scripts/check.sh の失敗ログ末尾40行
# @exitcode 0 許可（変更なし／キャッシュ合格／check.sh 合格／check.sh 不在／連続失敗で警告降格）
# @exitcode 2 ブロック（scripts/check.sh が失敗。修正してから作業を終える）
# @see scripts/check.sh 品質ゲートの唯一の入口（ADR-0004）
set -u

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# stdin（フック JSON）は分岐前に必ず読み切る
input=$(cat)

# ゲート対象の変更がなければ通す
changes=$(git status --porcelain 2>/dev/null)
[ -z "$changes" ] && exit 0

# check.sh が無ければ通す（session-start が警告済み）
# 実行ビットの有無では判定しない: 下で `bash scripts/check.sh` として呼ぶため実行ビットは不要で、
# mode が落ちた環境（Windows/マウント FS/zip 展開）でゲートが黙って無効化されるのを防ぐ
[ -f scripts/check.sh ] || exit 0

# 合格キャッシュ: 変更状態のハッシュが前回合格と同じならスキップ
# （diff に現れない未追跡ファイルの内容もハッシュに含める）
state_hash=$( (
  git status --porcelain
  git diff
  git diff --cached
  git ls-files --others --exclude-standard -z | xargs -0 -r sha1sum
) 2>/dev/null | sha1sum | cut -d' ' -f1)
cache_file=".git/deb-quality-gate.pass"
# state_hash が空（sha1sum 不在など）ならキャッシュは一切使わない。
# 空のまま読み書きすると「常に前回と一致」＝ゲート恒久停止になるため、必ずゲートを走らせる
if [ -n "$state_hash" ] && [ -f "$cache_file" ] &&
   [ "$(cat "$cache_file" 2>/dev/null)" = "$state_hash" ]; then
  exit 0
fi

# 無限ループ防止: stop_hook_active が true（前回もこのフックが失敗）なら警告のみ
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  echo "品質ゲートが連続で失敗しています。scripts/check.sh の失敗内容をユーザーに報告してください。" >&2
  exit 0
fi

log=$(bash scripts/check.sh 2>&1)
if [ $? -ne 0 ]; then
  echo "品質ゲート失敗: scripts/check.sh が失敗しました。修正してから作業を終えてください。" >&2
  echo "--- 失敗ログ（末尾40行） ---" >&2
  echo "$log" | tail -40 >&2
  exit 2
fi

[ -n "$state_hash" ] && echo "$state_hash" > "$cache_file" 2>/dev/null
exit 0
