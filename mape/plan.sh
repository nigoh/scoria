#!/usr/bin/env bash
# @file mape/plan.sh
# @brief P — Plan（計画）。ADR-0010 / ADR-0011。
# @description
#   proposals.tsv を読み、リスク3分類（自動/承認/相談）のチェックリストとして
#   GitHub イシュー本文（$MAPE_STATE_DIR/issue-body.md）を生成する。投稿はスキル側が MCP で行う。
#   完了項目は実行台帳（ledger.jsonl）の green から <details> に畳み、板をスリムに保つ（ADR-0011）。
#
#   このスクリプト自体は knowledge/ を一切書き換えない（生成物は state/ のみ）。
#   auto は既定チェック済み `[x]`、approve / consult は未チェック `[ ]` で描画する（人が選ぶ）。
#
# @noargs
# @stdout 生成した issue-body.md のパス
# @stderr 進行ログ（`[mape] plan 完了 → …`）
# @exitcode 0 成功
# @exitcode 1 cd 失敗・proposals.tsv 不在（mape_die）
# @see mape/analyze.sh 先に実行して proposals.tsv を用意する必要がある
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

cd "$MAPE_ROOT" || mape_die "cd 失敗"
mape_ensure_state

tsv="$MAPE_STATE_DIR/proposals.tsv"
[ -f "$tsv" ] || mape_die "proposals.tsv が無い。先に mape/analyze.sh を実行する"
env_file="$MAPE_STATE_DIR/monitor.env"
mape_load_env "$env_file"   # source しない（コマンド注入対策。lib.sh 参照）

out="$MAPE_STATE_DIR/issue-body.md"

# @internal
# @description 指定 tier の項目をチェックリスト行として出力する。
# @arg $1 string 描画対象の tier（auto|approve|consult）
# @arg $2 string チェックボックスの中身（"x"=既定チェック済み / " "=未チェック）
# @stdout `- [x|( )] (<prio>, score <score>) <text>` の行。該当なしなら「- （なし）」
# @exitcode 0 常に成功
emit_section() {
  local want="$1" checkbox="$2" tier prio impact effort score text found=0
  while IFS=$'\t' read -r tier prio impact effort score text; do
    [ "$tier" = "$want" ] || continue
    echo "- [$checkbox] ($prio, score $score) $text"
    found=1
  done < "$tsv"
  [ "$found" -eq 0 ] && echo "- （なし）"
}

# @internal
# @description 実行台帳（ledger.jsonl）の green を「完了ログ」の行として出力する（ADR-0011: 板をスリムに保つ）。
#   jq / python3 の二重バックエンドは同一入力で同一出力になるよう揃えてある（破損行の per-line 無視・
#   pr 欠落/null を空文字で描画）。揃えないとインストール済みパーサ次第で掲示内容が変わる。
# @noargs
# @stdout `- <item> → PR #<n>（<ts>）` の行（green の件数だけ）。台帳不在なら無出力
# @exitcode 0 常に成功
emit_done_log() {
  local ledger="$MAPE_STATE_DIR/ledger.jsonl" line
  [ -f "$ledger" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    # 1行ずつ処理する（ストリーム全体を jq に渡すと不正な1行で中断し、以降の green を落とす）。
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      printf '%s\n' "$line" | jq -r 'select(.result=="green") | "- \(.item) → PR #\(.pr // "")（\(.ts)）"' 2>/dev/null
    done < "$ledger"
  else
    python3 - "$ledger" <<'PY' 2>/dev/null
import json,sys
# errors="replace" で不正 UTF-8 を許容。非オブジェクト行は isinstance で弾く（.get で落ちると
# その行以降の green を完了ログから取りこぼす。jq 経路の per-line 耐性と挙動を揃える）。
for ln in open(sys.argv[1],encoding="utf-8",errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: r=json.loads(ln)
    except Exception: continue
    if isinstance(r,dict) and r.get("result")=="green":
        # pr 欠落/null は空文字で描画（jq の `.pr // ""` と揃える。None を "None" と出さない）。
        print(f"- {r.get('item')} → PR #{r.get('pr') or ''}（{r.get('ts')}）")
PY
  fi
}
done_log=$(emit_done_log)
done_n=$(printf '%s' "$done_log" | grep -c . 2>/dev/null || true); done_n=${done_n:-0}

{
  echo "# 🌙 MAPE-K 夜間改善レポート — ${MAPE_TS:-?} (cycle ${MAPE_CYCLE:-?})"
  echo
  echo "> 自動生成（\`mape/plan.sh\`, ADR-0010/0011）。夜間に Monitor→Analyze→Plan を回した結果です。"
  echo "> **あなたはチェックを入れるだけ**。Execute が「チェック済み・未着手」を1周1件だけ安全に実装します。"
  echo
  echo "健全性: gate=${MAPE_GATE:-skip}(${MAPE_GATE_S:-?}s) / TODO=${MAPE_TODO:-?} / 最長SKILL=${MAPE_MAX_SKILL:-?}/500 / CLAUDE.md=${MAPE_CLAUDE_MD:-?}/200 / ADR=${MAPE_ADR:-?}"
  echo
  echo "## ✅ 自動（無害・可逆：チェック不要で PR まで実装。マージはしない）"
  echo
  emit_section auto "x"
  echo
  echo "> 自動項目は既定でチェック済み（\`[x]\`）です。実装してほしくないものは外してください。"
  echo
  echo "## 🟡 承認（挙動が変わる：**チェックした項目だけ**実装）"
  echo
  emit_section approve " "
  echo
  echo "## 🔴 相談（認証/課金/データ/秘密/デプロイ：チェックしても、まず質問します）"
  echo
  emit_section consult " "
  echo
  # 既知の軽微な表示上の限界（機能バグではない・自己修復する）:
  #   ledger で green だが BACKLOG のチェックボックスがまだ [ ] の項目（＝Execute が PR ブランチで
  #   チェックを付けてから main へマージされるまでの窓）は、上の未着手セクションと下の完了ログの
  #   両方に出うる。二重実行は Execute 側の冪等（ledger green はスキップ）で防止済み。ここで
  #   完了ログ側を機械的に除外しないのは、ledger の item 文字列（Execute が渡す任意テキスト）と
  #   proposals の全文が一致保証されず、テキスト一致による除外が不確実で誤った安心を与えるため。
  #   マージで BACKLOG が [x]/アーカイブ化されれば解消する。
  echo "<details>"
  echo "<summary>✅ 完了ログ（${done_n} 件・実装 PR 済み。履歴の正本は knowledge/PROGRESS.md）</summary>"
  echo
  if [ "$done_n" -gt 0 ]; then echo "$done_log"; else echo "- （まだありません）"; fi
  echo
  echo "</details>"
  echo
  echo "---"
  echo
  echo "### 使い方 / ガードレール"
  echo
  echo "- 実装してほしい項目にチェックを入れてください。Execute はポーリングで拾います。"
  echo "- **1周1件**・**トピックブランチ + PR**・**main は直接触らない**・**本番/秘密/課金には触れない**。"
  echo "- 実装した項目には Execute が \`→ PR #N\` とコメントし、チェックを入れて二重実行を防ぎます（冪等性）。"
  echo "- テストが緑になった変更だけ PR にします。赤なら変更を破棄し、失敗を \`knowledge/PROGRESS.md\` に記録します。"
  echo "- サーキットブレーカー: 同じ失敗や revert が続いたら Execute を止めて通知します。"
  echo "- 未チェックのまま時間が過ぎた項目は自動アーカイブされます（計画を腐らせない）。"
  echo
  echo "<!-- mape:cycle=${MAPE_CYCLE:-?} generated-by=mape/plan.sh -->"
} > "$out"

mape_log "plan 完了 → $out"
echo "$out"
