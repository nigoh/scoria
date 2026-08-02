#!/usr/bin/env bash
# @file scripts/check-skill-sync.sh
# @brief CLAUDE.md の一覧表（スキル / エージェント）と .claude/ の実体の同期検証。
# @description
#   CLAUDE.md の一覧表（スキル / エージェント）と実体（.claude/skills, .claude/agents）の同期を機械検証する。
#   scripts/check.sh から呼ばれる品質ゲート（ADR-0004。ゲートは check.sh 単一入口に足す）。
#
#   背景: 「スキル・エージェントを増減したら CLAUDE.md の一覧表と同期する」（.claude/rules/claude-config.md）は
#         これまで人手・doc-auditor 頼みだった。ここで機械検証し、乖離を PR 前に落とす。
#
#   検査:
#     1) .claude/skills/<name>/SKILL.md がある各スキルが、CLAUDE.md「## スキル」表に `/<name>` として載っている（両方向）
#     2) .claude/agents/<name>.md がある各エージェントが、CLAUDE.md「## エージェント」表の1列目に載っている（両方向）
# @exitcode 0 一覧と実体が一致（CLAUDE.md が無い場合も 1 で終了する点に注意）
# @exitcode 1 乖離を検知、または CLAUDE.md が存在しない
# @stdout 合格時の件数要約
# @stderr 乖離ごとの "NG(skill-sync): …"
set -u

cd "$(dirname "$0")/.." || exit 1

fail=0
# @description 乖離を報告し fail フラグを立てる（1件目で打ち切らず全件を報告するため）。
# @internal
# @arg $@ string 乖離の説明
# @set fail int 1
# @stderr "NG(skill-sync): 説明"
ng() { echo "NG(skill-sync): $*" >&2; fail=1; }

[ -f CLAUDE.md ] || { echo "skill-sync: CLAUDE.md が無い"; exit 1; }

# 指定セクション（"## 見出し" 〜 次の "## "）内の表行だけを取り出す。
# 二つの誤検知を防ぐ:
#  a) 見出しは「完全一致 or 直後が括弧」でのみ一致させ、かつ**最初に一致したセクションだけ**を
#     読む。部分一致のままだと `## スキルの書き方` のような別セクションの表行まで宣言と見なし、
#     そこに出てくる例示コマンド（`/sample`）を「実体の無い幽霊スキル」として偽赤にする。
#  b) セクション内のコードフェンス（``` / ~~~）で囲まれた表は宣言と見なさない。README 的な
#     書式例を実在エントリと誤認しないため（幽霊エントリの偽赤防止）。
#     フェンスで表全体を隠した場合は declared が空になり、実体側が「一覧に無い」で赤になる
#     （fail-closed は維持される）。
# @description 指定セクション（"## 見出し" 〜 次の "## "）内の表行だけを取り出す。
#   見出しは完全一致 or 直後が括弧でのみ一致させ、最初に一致したセクションだけを読む。
#   セクション内のコードフェンス（``` / ~~~）で囲まれた表は宣言と見なさない（上のコメント参照）。
# @internal
# @arg $1 string セクション見出しの awk 正規表現（^## 名前$|^## 名前（ の形）。
#   awk -v の未定義エスケープ解釈が実装依存になるためバックスラッシュを使わず、丸括弧は [(] で表現する。
# @stdout 該当セクション内の表行（`|` で始まる行）
section_rows() { # $1 = セクション見出しの awk 正規表現（^## 名前$|^## 名前（ の形）
  # 見出しパターンは **ENVIRON 経由**で渡す。`awk -v` は値のエスケープシーケンスを解釈するため、
  # `\(` のような未定義エスケープの扱いが実装依存になる（mawk/nawk はバックスラッシュを残すが
  # original-awk(BWK) は剥がすため `^## 名前(` という不正な正規表現になり、致命エラーで
  # セクションが丸ごと空になる ＝ インストール済み awk 次第でゲート結果が変わる非決定論）。
  # 同じ理由で呼び出し側のパターンにもバックスラッシュを使わず、丸括弧は [(] で表現する。
  # （mape/lib.sh に同趣旨の既知事項あり: 「awk -v は \n/\\ を解釈するため不安全」）
  SKILLSYNC_START="$1" awk '
    BEGIN { start = ENVIRON["SKILLSYNC_START"] }
    !inseg && !done && $0 ~ start { inseg=1; fence=""; next }
    inseg && /^## /   { inseg=0; done=1 }
    inseg && match($0, /^[[:space:]]*(```|~~~)/) {
      m = substr($0, RSTART, RLENGTH); gsub(/[[:space:]]/, "", m); m = substr(m, 1, 3)
      if (fence == "")      { fence = m }
      else if (m == fence)  { fence = "" }
      next
    }
    inseg && fence == "" && /^\|/ { print }
  ' CLAUDE.md
}

# 集合の差分を報告する共通関数
# @description 宣言（CLAUDE.md 一覧）と実体（.claude/ 配下）の集合差分を両方向で報告する。
#   「一覧にあるが実体が無い（幽霊）」と「実体はあるが一覧に無い（更新漏れ）」を区別して出す。
# @internal
# @arg $1 string 種別ラベル（"スキル" / "エージェント"）
# @arg $2 string 宣言側の名前一覧（改行区切り）
# @arg $3 string 実体側の名前一覧（改行区切り）
# @set fail int 差分があれば ng() 経由で 1
# @stderr 差分ごとの "NG(skill-sync): …"
compare() { # $1=種別ラベル $2=宣言(改行区切り) $3=実体(改行区切り)
  local label="$1" declared="$2" actual="$3" n
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    printf '%s\n' "$actual" | grep -qx "$n" || ng "$label '$n' は CLAUDE.md にあるが実体が無い（一覧と実体の乖離）"
  done <<< "$declared"
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    printf '%s\n' "$declared" | grep -qx "$n" || ng "$label '$n' は実体があるが CLAUDE.md 一覧に無い（一覧を更新する）"
  done <<< "$actual"
}

# --- 1. スキル ---
# 表の「1列目（コマンド列）」だけを対象にする。行全体を grep すると、説明列に他スキル名
# （`/round` 等）が混じった行で「宣言済み」と誤認し、実体はあるが行の無いスキルのドリフトを
# 見逃す（エージェント側と非対称になる）。
declared_skills=$(section_rows '^## スキル$|^## スキル（|^## スキル[(]' \
  | sed -E 's/^\|[[:space:]]*//; s/[[:space:]]*\|.*$//' \
  | grep -oE '`/[a-z0-9-]+`' | tr -d '`/' | sort -u)
actual_skills=$(for d in .claude/skills/*/; do [ -f "${d}SKILL.md" ] && basename "$d"; done | sort -u)
compare "スキル" "$declared_skills" "$actual_skills"

# --- 2. エージェント ---
declared_agents=$(section_rows '^## エージェント$|^## エージェント（|^## エージェント[(]' \
  | sed -E 's/^\|[[:space:]]*//; s/[[:space:]]*\|.*$//' \
  | grep -E '^[a-z][a-z0-9-]+$' | sort -u)
actual_agents=$(for f in .claude/agents/*.md; do [ -f "$f" ] && basename "$f" .md; done | sort -u)
compare "エージェント" "$declared_agents" "$actual_agents"

if [ "$fail" -ne 0 ]; then
  echo "skill-sync: 失敗" >&2
  exit 1
fi
echo "skill-sync: 合格（スキル $(printf '%s\n' "$actual_skills" | grep -c .) 件 / エージェント $(printf '%s\n' "$actual_agents" | grep -c .) 件が一覧と一致）"
