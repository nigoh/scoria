#!/usr/bin/env bash
# @file mape/safe-state.sh
# @brief 安全状態（safe-state）判定。ADR-0016 / NFR-SAFE-001 / NFR-SAFE-002。
# @description
#   MAPE-K の散在した fail-safe 断片（circuit-breaker・赤→破棄・1周1件・consult 除外・guard）を
#   「安全状態」という1つの不変条件へ集約する。無人 Execute はこの判定が MAPE_SAFE=1 の
#   ときだけ許される（危険時は Execute を抑止＝安全側へ縮退）。
#
#   判定する不変条件（すべて満たすとき MAPE_SAFE=1）:
#     1) 保護ブランチ(main/master)上でない（トピックブランチ + PR 運用。CLAUDE.md 絶対原則）
#     2) knowledge/ 整合性が green（mape_verify_knowledge。細胞の DNA が壊れていない）
#     3) 作業ツリーがクリーン（未コミット変更に無人 Execute を重ねない）
#     4) サーキットブレーカーが既知かつ非 tripped（暴走検知が発火していない）
#
#   フェイルセーフ: 判定情報が得られない（git 不在・detached HEAD・mape_verify_knowledge 未定義など）
#   ときは MAPE_SAFE=0（不安全）へ倒す（guard-* と同じ安全側）。移植性: LC_ALL=C・git branch --show-current。
#   ブレーカー status の 0/3 以外（例 exit 4＝パーサ不在で判定不能）は「状態不明」として unsafe に畳む。
#
# @noargs
# @stdout `MAPE_SAFE=0|1` と `MAPE_SAFE_REASONS=<理由;…>` の2行（$MAPE_STATE_DIR/safe.env にも保存）
# @exitcode 0 安全（MAPE_SAFE=1。無人 Execute を許してよい）
# @exitcode 1 不安全（MAPE_SAFE=0。read-only なので判定のみで何も破壊しない）
# @see mape/circuit-breaker.sh
# @see docs/adr/0016-mape-k-safe-state-model.md
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mape_ensure_state

MAPE_GIT_ROOT="${MAPE_GIT_ROOT:-$MAPE_ROOT}"
PROTECTED_BRANCHES='main|master'

reasons=""
# @internal
# @description 不安全と判定した理由を `; ` 区切りで $reasons へ積む。1件でも積まれれば MAPE_SAFE=0。
# @arg $1 string 理由（人が読む短文）
# @set reasons string 積み上げた理由の連結文字列
# @exitcode 0 常に成功
add_reason() { reasons="${reasons:+$reasons; }$1"; }

git_ok=0
if command -v git >/dev/null 2>&1 \
   && git -C "$MAPE_GIT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_ok=1
fi

# 1) 保護ブランチ上でない
if [ "$git_ok" -ne 1 ]; then
  add_reason "git で検査不可（不在/非作業ツリー）"
else
  branch=$(git -C "$MAPE_GIT_ROOT" branch --show-current 2>/dev/null || true)
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    add_reason "ブランチ不明（detached HEAD/古い git 等）"
  elif printf '%s' "$branch" | LC_ALL=C grep -Eq "^(${PROTECTED_BRANCHES})$"; then
    add_reason "保護ブランチ上（$branch）"
  fi
fi

# 2) knowledge/ 整合性 green（DNA ガーディアン）
if declare -F mape_verify_knowledge >/dev/null 2>&1; then
  mape_verify_knowledge >/dev/null 2>&1 || add_reason "knowledge 整合性 NG（DNA 破損）"
else
  add_reason "mape_verify_knowledge 未提供（整合性を確認できない）"
fi

# 3) 作業ツリーがクリーン（未コミット変更に無人 Execute を重ねない）。
# ただし MAPE 自身の証跡ディレクトリ mape/state/ は除外する。M→A→P は毎周回ここを再生成して
# working tree を汚すため、含めると「自分の churn で自分の Execute を止める」フェイルオープンならぬ
# フェイルクローズ暴発になる。除外するのは生成物のみ（コードではない）で、コード/knowledge の未コミット
# 変更は依然 unsafe に倒すので安全境界は弱まらない。
if [ "$git_ok" -eq 1 ]; then
  dirty=$(LC_ALL=C git -C "$MAPE_GIT_ROOT" status --porcelain -- . ':(exclude)mape/state' 2>/dev/null)
  [ -n "$dirty" ] && add_reason "作業ツリーに未コミット変更あり"
fi

# 4) サーキットブレーカーが既知かつ非 tripped
cb="$MAPE_LIB_DIR/circuit-breaker.sh"
if [ -f "$cb" ]; then
  bash "$cb" status >/dev/null 2>&1; rc=$?
  case "$rc" in
    0) : ;;
    3) add_reason "サーキットブレーカー tripped" ;;
    *) add_reason "ブレーカー状態不明（status rc=$rc）" ;;
  esac
else
  add_reason "circuit-breaker.sh 不在"
fi

if [ -z "$reasons" ]; then safe=1; else safe=0; fi

{
  echo "MAPE_SAFE=$safe"
  echo "MAPE_SAFE_REASONS=$reasons"
} | tee "$MAPE_STATE_DIR/safe.env"

[ "$safe" -eq 1 ]
