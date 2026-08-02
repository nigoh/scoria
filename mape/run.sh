#!/usr/bin/env bash
# @file mape/run.sh
# @brief MAPE-K の M→A→P を1周まわす統合ランナー。ADR-0010。
# @description
#   読み取り中心（安価・安全）。夜通し何度でも回してよい。実装（Execute）は含まない。
#
#   使い方:
#     bash mape/run.sh            # M→A→P を回し、state/ に成果物を出す（knowledge は触らない = ドライラン）
#     bash mape/run.sh --record   # HEALTH.md / BACKLOG.md / PROGRESS.md も更新する（本番の夜間周回）
#
#   出力の要: $MAPE_STATE_DIR/issue-body.md（Plan が作る掲示用チェックリスト）
#
#   実行順: safe-state 判定 → M(monitor) → K→A(efficacy) → A(analyze) → P(plan) →
#   safe-state=0 なら掲示本文の先頭へ Execute 抑止バナーを差し込む（NFR-SAFE-002）。
#
# @option --record knowledge/（HEALTH / BACKLOG / PROGRESS）も更新する。省略時はドライラン
# @stdout 生成した issue-body.md のパス
# @stderr 各フェーズの進行ログ（`[mape] M: monitor…` など）
# @exitcode 0 成功（safe-state=0 でも 0。抑止は掲示本文のバナーで表現する）
# @exitcode 1 未知の引数・cd 失敗、または下位スクリプトの失敗（mape_die / set -u なしの伝播）
# @see mape/safe-state.sh
# @see docs/adr/0016-mape-k-safe-state-model.md
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

record=0
for arg in "$@"; do
  case "$arg" in
    --record) record=1 ;;
    *) mape_die "未知の引数: $arg" ;;
  esac
done

cd "$MAPE_ROOT" || mape_die "cd 失敗"

# --- 安全状態（safe-state）判定。ADR-0016 / NFR-SAFE-001。M→A→P より前に評価し危険時は Execute を抑止。---
# 先に safe.env を **フェイルセーフ既定（unsafe）** で上書きしてから評価する。こうしないと
# safe-state.sh が（クラッシュ等で）今周回に safe.env を書けなかったとき、前周回の古い
# MAPE_SAFE=1 を信用して fail-open する（危険時に Execute 抑止バナーを落とす）。
mape_ensure_state
printf 'MAPE_SAFE=0\nMAPE_SAFE_REASONS=safe-state 未評価（フェイルセーフ）\n' > "$MAPE_STATE_DIR/safe.env"
bash mape/safe-state.sh >/dev/null 2>&1 || true   # 終了コードは無視し safe.env の内容で判断する
mape_safe=0; mape_safe_reasons="safe.env 欠落"
if [ -f "$MAPE_STATE_DIR/safe.env" ]; then
  # source しない（branch 名など外部制御データを含むため。ADR-0010 の膜）
  mape_safe=$(grep -E '^MAPE_SAFE=' "$MAPE_STATE_DIR/safe.env" | tail -1 | cut -d= -f2-)
  mape_safe_reasons=$(grep -E '^MAPE_SAFE_REASONS=' "$MAPE_STATE_DIR/safe.env" | tail -1 | cut -d= -f2-)
fi
case "${mape_safe:-}" in 0|1) ;; *) mape_safe=0; mape_safe_reasons="MAPE_SAFE 不正値（フェイルセーフ）" ;; esac
# HEALTH の note 列へ畳む安全タグ（列は増やさない。無毒化してから）。monitor が拾う。
if [ "$mape_safe" -eq 1 ]; then export MAPE_SAFE_NOTE="safe"
else export MAPE_SAFE_NOTE="unsafe($(mape_sanitize_signal "$mape_safe_reasons"))"; fi

mon_args=(--with-gate); ana_args=()
if [ "$record" -eq 1 ]; then mon_args+=(--record); ana_args+=(--update-knowledge); fi

mape_log "M: monitor…"
bash mape/monitor.sh "${mon_args[@]}" >/dev/null

# 効き目学習（self-optimization。ADR-0017）: 委託台帳から重点テーマ別の効き目 efficacy.tsv を再計算し、
# Analyze の採点へ還元する。read-only・派生物なので A の前に必ず更新する（失敗しても中立で続行）。
mape_log "K→A: efficacy…"
bash mape/efficacy.sh >/dev/null 2>&1 || true

mape_log "A: analyze…"
bash mape/analyze.sh "${ana_args[@]}" >/dev/null

mape_log "P: plan…"
bash mape/plan.sh >/dev/null

# --- Execute 抑止アノテーション（NFR-SAFE-002）: safe-state=0 のとき掲示本文の先頭に抑止バナーを差し込む ---
if [ "$mape_safe" -eq 0 ]; then
  _body="$MAPE_STATE_DIR/issue-body.md"
  if [ -f "$_body" ]; then
    _tmp="$_body.safe.tmp"
    {
      echo "> 🛑 **safe-state=0（Execute 抑止中）** — 理由: $(mape_sanitize_signal "$mape_safe_reasons")"
      echo "> 安全状態に復帰するまで無人 Execute は行わない（NFR-SAFE-002 / ADR-0016）。"
      echo
      cat "$_body"
    } > "$_tmp" && mv "$_tmp" "$_body"
  fi
  mape_log "safe-state=0: Execute を抑止（$mape_safe_reasons）"
fi

# --record のときは PROGRESS に monitor サイクルを1件、末尾追記する
if [ "$record" -eq 1 ] && [ -f "$MAPE_PROGRESS" ]; then
  mape_load_env "$MAPE_STATE_DIR/monitor.env"   # source しない（コマンド注入対策）
  {
    echo
    echo "## ${MAPE_TS} — monitor (cycle ${MAPE_CYCLE})"
    echo "- 対象: リポジトリ全体のシグナル観測"
    echo "- やったこと: M→A→P を実行し計画イシュー本文を生成"
    echo "- 結果: gate=${MAPE_GATE}(${MAPE_GATE_S}s) / TODO=${MAPE_TODO} / 提案 $(wc -l < "$MAPE_STATE_DIR/proposals.tsv" | tr -d ' ') 件"
    echo "- 考察: HEALTH.md に cycle ${MAPE_CYCLE} を記録。推移は同ファイル参照"
    if [ "$mape_safe" -eq 1 ]; then
      echo "- 次に必要になった作業: Execute がチェック済み項目を1件消化"
    else
      echo "- 次に必要になった作業: safe-state=0 のため Execute を抑止（${mape_safe_reasons}）。安全状態へ復帰させる"
    fi
  } >> "$MAPE_PROGRESS"
  mape_log "PROGRESS.md に monitor サイクルを追記"
fi

echo "$MAPE_STATE_DIR/issue-body.md"
mape_log "M→A→P 完了。掲示用本文: $MAPE_STATE_DIR/issue-body.md"
