#!/usr/bin/env bash
# @file mape/monitor.sh
# @brief M — Monitor（監視）。ADR-0010。
# @description
#   リポジトリのシグナルを集めて $MAPE_STATE_DIR/monitor.env と monitor.md に書き出す。
#   読み取り専用（--record を渡したときだけ knowledge/HEALTH.md に1行追記する）。
#
#   使い方:
#     bash mape/monitor.sh              # 収集のみ（state/ に出力、HEALTH は触らない）
#     bash mape/monitor.sh --with-gate  # scripts/check.sh を実行して合否と所要秒も測る
#     bash mape/monitor.sh --with-gate --record   # HEALTH.md に推移を1行追記
#
#   注意: --with-gate は check.sh を回す。check.sh は mape テスト経由で monitor を呼ぶため、
#         テストからは --with-gate を使わない（無限再帰防止）。
#
#   収集する指標: TODO/FIXME 件数・シェルスクリプト数・最長 SKILL.md 行数・CLAUDE.md 行数・
#   ADR 数・churn 首位ファイル・品質ゲート合否/所要秒・最終 HEALTH 追記からの経過時間(h)。
#
# @option --with-gate scripts/check.sh を実行して gate/gate_s を測る（MAPE_NO_GATE=1 なら無視）
# @option --record knowledge/HEALTH.md に推移を1行追記する（唯一の破壊的操作）
# @stdout HEALTH.md の推移行（--record の有無に関わらず1行出す）
# @stderr 進行ログ（`[mape] …`）
# @exitcode 0 成功
# @exitcode 1 未知の引数・cd 失敗（mape_die）
# @see mape/lib.sh
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

with_gate=0; record=0
for arg in "$@"; do
  case "$arg" in
    --with-gate) with_gate=1 ;;
    --record)    record=1 ;;
    *) mape_die "未知の引数: $arg" ;;
  esac
done

cd "$MAPE_ROOT" || mape_die "cd 失敗"
mape_ensure_state

# --- シグナル収集 ---
# TODO/FIXME は「コメントマーカー」に限定して数える（散文中の "TODO 12→3" 等の誤検知を避ける）。
# マッチ: 行コメント記号直後（# // <!-- /* *）か、直後がコロンのもの。
todo=$(grep -rIn --exclude-dir=.git --exclude-dir=knowledge --exclude-dir=mape \
        -E '(#|//|<!--|/\*|\*)[[:space:]]*(TODO|FIXME)\b|\b(TODO|FIXME):' . 2>/dev/null | wc -l | tr -d ' ')

scripts=$(find . -path ./.git -prune -o -name '*.sh' -type f -print 2>/dev/null | wc -l | tr -d ' ')

max_skill=0
for s in .claude/skills/*/SKILL.md; do
  [ -f "$s" ] || continue
  n=$(wc -l < "$s" | tr -d ' ')
  [ "$n" -gt "$max_skill" ] && max_skill=$n
done

claude_md=0
[ -f CLAUDE.md ] && claude_md=$(wc -l < CLAUDE.md | tr -d ' ')

adr=$(find docs/adr -maxdepth 1 -name '[0-9]*.md' -type f 2>/dev/null | wc -l | tr -d ' ')

# 変更が集中する箇所（churn）: 直近30コミットで最も触られたファイル。
# MAPE 自身が毎周回書き換える帳簿（knowledge/・mape/state/）は除外する。含めると churn 首位が
# 常に自分の生成物になり、analyze が自己参照ノイズを BACKLOG へ恒久追記して肥大するため
# （TODO 集計が knowledge/mape を除外しているのと対称にする）。
churn_top=$(git log -n 30 --name-only --pretty=format: 2>/dev/null \
            | grep -v '^$' | grep -vE '^(knowledge/|mape/state/)' \
            | sort | uniq -c | sort -rn | head -1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//')
[ -z "$churn_top" ] && churn_top="-"
# churn_top は git 追跡ファイル名＝ブランチに commit した者が中身を決められる外部制御データ。
# monitor.env / monitor.md / 下流の計画イシュー・無人 Execute へ流す前に無毒化する（膜。ADR-0010）。
churn_top=$(mape_sanitize_signal "$churn_top")
[ -z "$churn_top" ] && churn_top="-"

# 品質ゲート（任意）
# 再帰ガード: check.sh 経由（= MAPE_NO_GATE=1）では --with-gate を無視する。
# check.sh は mape テストを回し、テストは monitor を呼ぶため、ここでゲートを走らせると無限再帰になる。
gate="skip"; gate_s="-"
if [ "$with_gate" -eq 1 ] && [ "${MAPE_NO_GATE:-0}" != "1" ]; then
  start=$(date +%s)
  if bash scripts/check.sh >"$MAPE_STATE_DIR/gate.log" 2>&1; then gate="pass"; else gate="fail"; fi
  gate_s=$(( $(date +%s) - start ))
fi

ts=$(mape_now)

# サイクル番号: HEALTH の既存データ行数 + 1
cycle=1
if [ -f "$MAPE_HEALTH" ]; then
  existing=$(grep -cE '^\| [0-9]{4}-' "$MAPE_HEALTH" 2>/dev/null || true)
  existing=${existing:-0}
  cycle=$(( existing + 1 ))
fi

# 心拍/休眠自己検知（ADR-0014）: 最終 HEALTH データ行の ts からの経過時間(h)。0/1 行・破損 ts は '-'
# （判定不能）。この --record 追記は下（144行付近の「HEALTH.md へ追記」節）なので、
# 現在値は「最終 *記録済み* 周回からの経過」。
last_ts=""
if [ -f "$MAPE_HEALTH" ]; then
  last_ts=$(grep -E '^\| [0-9]{4}-[0-9]{2}-[0-9]{2}T' "$MAPE_HEALTH" 2>/dev/null \
            | tail -1 | sed -E 's/^\| ([^ ]+) \|.*/\1/')
fi
stale_h="-"
if [ -n "$last_ts" ]; then
  le=$(mape_epoch_utc "$last_ts"); ne=$(date -u +%s 2>/dev/null)
  if [ -n "$le" ] && [ -n "$ne" ] && [ "$ne" -ge "$le" ] 2>/dev/null; then
    stale_h=$(( (ne - le) / 3600 ))
  fi
fi

# --- 出力: monitor.env（sourceable） ---
{
  echo "MAPE_TS=$ts"
  echo "MAPE_CYCLE=$cycle"
  echo "MAPE_GATE=$gate"
  echo "MAPE_GATE_S=$gate_s"
  echo "MAPE_TODO=$todo"
  echo "MAPE_SCRIPTS=$scripts"
  echo "MAPE_MAX_SKILL=$max_skill"
  echo "MAPE_CLAUDE_MD=$claude_md"
  echo "MAPE_ADR=$adr"
  echo "MAPE_CHURN_TOP=$churn_top"
  echo "MAPE_STALE_H=$stale_h"
} > "$MAPE_STATE_DIR/monitor.env"

# --- 出力: monitor.md（人が読む要約） ---
{
  echo "# Monitor レポート — $ts (cycle $cycle)"
  echo
  echo "| 指標 | 値 |"
  echo "|---|---|"
  echo "| gate | $gate ($gate_s s) |"
  echo "| todo/fixme | $todo |"
  echo "| shell scripts | $scripts |"
  echo "| 最長 SKILL 行 | $max_skill / 500 |"
  echo "| CLAUDE.md 行 | $claude_md / 200 |"
  echo "| ADR 数 | $adr |"
  echo "| churn 首位 | $churn_top |"
} > "$MAPE_STATE_DIR/monitor.md"

# --- HEALTH.md へ追記（--record のときだけ） ---
row="| $ts | $cycle | $gate | $gate_s | $todo | $scripts | $max_skill | $claude_md | $adr | monitor${MAPE_SAFE_NOTE:+ $MAPE_SAFE_NOTE} |"
if [ "$record" -eq 1 ] && [ -f "$MAPE_HEALTH" ]; then
  printf '%s\n' "$row" >> "$MAPE_HEALTH"
  mape_log "HEALTH.md に cycle $cycle を追記"
fi

echo "$row"
mape_log "monitor 完了 → $MAPE_STATE_DIR/monitor.env"
