#!/usr/bin/env bash
# @file mape/analyze.sh
# @brief A — Analyze（分析）。ADR-0010。
# @description
#   monitor.env の生シグナルを「症状」に変換し、根拠とインパクト×労力スコア付きの改善案を作る。
#   POLICY.md の却下ログでフィルタし、リスク分類（consult 危険側優先）を付ける。
#   読み取り専用（--update-knowledge を渡したときだけ BACKLOG.md に新候補を追記する）。
#
#   出力: $MAPE_STATE_DIR/proposals.tsv（tier\tpriority\timpact\teffort\tscore\ttext）
#         $MAPE_STATE_DIR/analysis.md（人が読む症状＋提案）
#
#   処理の段: 1) シグナル由来の提案（一過性・BACKLOG へ焼き付けない）→ 2) BACKLOG「## 候補」の
#   取り込み（隔離済み・台帳 done は除外）→ 3) スコア降順で proposals.tsv 確定 → 4) analysis.md →
#   5) --update-knowledge のときだけ新候補を BACKLOG へ永続化。
#
# @option --update-knowledge knowledge/BACKLOG.md に新候補を追記する（唯一の破壊的操作）
# @stderr 進行ログ（`[mape] analyze 完了 → 提案 N 件 / 除外 M 件`）
# @exitcode 0 成功
# @exitcode 1 未知の引数・cd 失敗・monitor.env 不在（mape_die）
# @see mape/monitor.sh 先に実行して monitor.env を用意する必要がある
# @see mape/lib.sh
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

update_knowledge=0
for arg in "$@"; do
  case "$arg" in
    --update-knowledge) update_knowledge=1 ;;
    *) mape_die "未知の引数: $arg" ;;
  esac
done

cd "$MAPE_ROOT" || mape_die "cd 失敗"
mape_ensure_state

env_file="$MAPE_STATE_DIR/monitor.env"
[ -f "$env_file" ] || mape_die "monitor.env が無い。先に mape/monitor.sh を実行する"
mape_load_env "$env_file"   # source しない（コマンド注入対策。lib.sh 参照）

raw="$MAPE_STATE_DIR/proposals.raw"
: > "$raw"
skipped="$MAPE_STATE_DIR/analysis.skipped"
: > "$skipped"

# @internal
# @description 提案を1件追加する。却下ログにマッチしたら skip。consult キーワードは分類を危険側へ上書き。
#   スコアは基本点（mape_score・純粋）に重点テーマ加点(§27)と効き目係数(§30)を合成するが、
#   tier は上書き（危険側）以外で動かさない＝**並べ替えのみ**で安全境界は侵さない。
# @arg $1 string tier（auto|approve|consult。未知/タイポは安全側 approve へ正規化）
# @arg $2 string 優先度（P1|P2|P3）
# @arg $3 int インパクト 1-5
# @arg $4 int 労力 1-5
# @arg $5 string 提案テキスト（根拠つき）
# @exitcode 0 常に成功（却下時も 0 を返し、テキストを analysis.skipped へ退避する）
emit() {
  local tier="$1" prio="$2" impact="$3" effort="$4" text="$5" score base boost theme factor
  if mape_is_rejected "$text"; then
    printf '%s\n' "$text" >> "$skipped"; return 0
  fi
  # danger-first: 本文に consult キーワードがあれば分類を consult へ引き上げる
  if [ "$(mape_classify "$text")" = "consult" ]; then tier="consult"; fi
  # 未知/タイポの tier は安全側(approve)へ正規化する（plan は auto/approve/consult しか
  # 描画しないため、正規化しないと BACKLOG の tier 誤記が計画本文から黙って消える）。
  case "$tier" in auto|approve|consult) ;; *) tier=approve ;; esac
  # スコア = 基本(mape_score・純粋・不変) に、重点テーマ加点(§27)と効き目係数(§30)を合成する。
  # テーマ非該当かつ効き目データ無しでは boost=0・factor=10 → score=base（挙動を完全保存）。
  # 係数は [7,12] クランプ・tier は不変 → **並べ替えのみ**（consult/Execute 条件は侵さない）。
  base=$(mape_score "$impact" "$effort")
  theme=$(mape_theme_of "$text")            # POLICY 重点テーマ照合は1回だけ（boost はその有無から導く）
  [ -n "$theme" ] && boost=3 || boost=0     # §27: 重点テーマ該当は同スコア帯で前へ
  factor=$(mape_effectiveness_factor "$theme")
  score=$(( ( (base + boost) * factor + 5 ) / 10 ))
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$tier" "$prio" "$impact" "$effort" "$score" "$text" >> "$raw"
}

# --- 1. シグナル由来の提案（実測値を根拠にする） ---
# gate は pass/fail の二値なのでバンドでなく従来どおり（赤は最優先）。
if [ "${MAPE_GATE:-skip}" = "fail" ]; then
  emit auto P1 5 2 "品質ゲート（scripts/check.sh）の赤を直す — 根拠: gate=fail（最優先。緑化するまで他を止める）"
fi

# 心拍/休眠自己検知（ADR-0014）: 最終 monitor から一定時間経過なら「ループ休眠」を最上位で通報。
# HEALTH が 0/1 行や ts 破損なら MAPE_STALE_H='-'（非数値）→ 何もしない（graceful degradation）。
# シグナル由来（step1）なので BACKLOG へ永続化されない（ゾンビ化しない）。tier は auto のまま。
case "${MAPE_STALE_H:--}" in
  ''|*[!0-9]*) : ;;
  *)
    if [ "${MAPE_STALE_H}" -ge "${MAPE_STALE_MAX_H:-36}" ] 2>/dev/null; then
      emit auto P1 5 1 "MAPE ループが ${MAPE_STALE_H} 時間 休眠 — Routine を確認（最終 HEALTH 追記からの経過。夜間 cron が回っていない可能性）"
    fi ;;
esac

# @internal
# @description 恒常性（ADR-0014）: 数値指標は POLICY の健全性バンド(setpoint)で判定し、逸脱幅に応じて提案する。
#   warn → P2/impact3、crit → P1/impact5（逸脱が深いほど優先度が上がる）。ok なら提案しない。
#   従来は max_skill/claude_md の固定しきい値のみで gate_s は無反応だった。バンド化で gate_s も監視。
# @arg $1 string 指標名（mape_band_status が解釈する metric）
# @arg $2 string 指標の現在値（非数値なら ok 扱いで無提案）
# @arg $3 string tier（auto|approve|consult）
# @arg $4 int 労力 1-5
# @arg $5 string 提案テキスト（`{v}`=値, `{s}`=band に置換される）
# @exitcode 0 常に成功
emit_band() {  # $1=metric $2=value $3=tier $4=effort $5=text（{v}=値, {s}=band に置換）
  local m="$1" v="$2" tier="$3" effort="$4" text="$5" band prio impact
  band=$(mape_band_status "$m" "$v")
  [ "$band" = ok ] && return 0
  if [ "$band" = crit ]; then prio=P1; impact=5; else prio=P2; impact=3; fi
  text=${text//\{v\}/$v}; text=${text//\{s\}/$band}
  emit "$tier" "$prio" "$impact" "$effort" "$text"
}
emit_band todo      "${MAPE_TODO:-0}"      auto    2 "TODO/FIXME を解消する（{v} 件・band={s}）— 根拠: 未完了マーカーが残存"
emit_band claude_md "${MAPE_CLAUDE_MD:-0}" auto    2 "CLAUDE.md を予算内に収める（{v}/200 行・band={s}）— 根拠: 200行予算に接近 / 手順は skills へ退避"
emit_band max_skill "${MAPE_MAX_SKILL:-0}" approve 3 "最長 SKILL.md を分割する（{v}/500 行・band={s}）— 根拠: 500行予算に接近 / progressive disclosure"
emit_band gate_s    "${MAPE_GATE_S:--}"    auto    2 "品質ゲート(check.sh)の実行時間が {v}s に肥大（band={s}）— 根拠: gate_s が健全band を超過 / フィードバック遅延"

# --- 微分感知（§28）: 絶対値が band 内でも、上昇が続いたら予算に接近する前に先回りで早期警告する。---
# @internal
# @description 微分感知（§28）。band=ok のときだけ出す。理由は二重防止と有効性の両面: (a) band が ok でない
#   指標は emit_band が既に発火するため二重掲示になる、(b) 逆に ok 帯に余白のある予算指標（claude_md
#   190/200・max_skill 500・gate_s）は「まだ band 内だが上昇が続く」を trend でしか拾えない。逆に
#   todo(既定 1/10) のように ok 幅が実質 0 の指標へ配線しても永久に発火しない（rising は現在値が上昇の
#   頂点＝正値を要求し、ok=0 と両立しない）。よって予算に余白のある指標にだけ配線する。
#   tier は元指標の分類のまま（安全境界不変・提案は追加のみ）。
#   テキストは一過性: step5 の永続化は $raw 全体を .signal_texts へ控えて除外するため BACKLOG に焼き付かない。
#   発火条件は「rising かつ連続3データ点以上かつ band=ok」。
# @arg $1 string 指標名
# @arg $2 string 指標の現在値
# @arg $3 string tier（元指標の分類のまま渡す）
# @arg $4 string 提案テキスト
# @exitcode 0 常に成功
# @see mape_trend
emit_trend() {  # $1=metric $2=value $3=tier $4=text
  local m="$1" v="$2" tier="$3" text="$4" tr dir streak band
  tr=$(mape_trend "$m"); dir=${tr%% *}; streak=${tr##* }
  [ "$dir" = rising ] || return 0
  case "$streak" in ''|*[!0-9]*) return 0;; esac
  [ "$streak" -ge 3 ] || return 0          # 3データ点＝連続上昇（＝band 内で右肩上がりが続く）
  band=$(mape_band_status "$m" "$v")
  [ "$band" = ok ] || return 0             # band を出た指標は emit_band が担当（trend は静かにする）
  emit "$tier" P2 3 3 "$text"
}
emit_trend claude_md "${MAPE_CLAUDE_MD:-0}" auto    "CLAUDE.md 行数が上昇トレンド継続中（band 内・200 行予算へ接近前の先回り）— 根拠: HEALTH claude_md が連続上昇"
emit_trend max_skill "${MAPE_MAX_SKILL:-0}" approve "最長 SKILL.md が上昇トレンド継続中（band 内・500 行予算へ接近前の先回り）— 根拠: HEALTH max_skill が連続上昇"
emit_trend gate_s    "${MAPE_GATE_S:--}"    auto    "品質ゲート実行時間が上昇トレンド継続中（band 内・肥大化の先回り）— 根拠: HEALTH gate_s が連続上昇"

if [ -n "${MAPE_CHURN_TOP:-}" ] && [ "${MAPE_CHURN_TOP}" != "-" ]; then
  # monitor が既に無毒化しているが、手で編集された/旧い monitor.env でも注入が下流（issue-body・
  # 無人 Execute）へ漏れないよう、提案テキストへ入れる直前に再度無毒化する（多層防御。ADR-0010）。
  csan=$(mape_sanitize_signal "$MAPE_CHURN_TOP")
  emit approve P3 3 3 "変更集中箇所 ${csan} のテスト強化/整理を検討 — 根拠: 直近30コミットの churn 首位 / 回帰リスク"
fi

# シグナル由来提案のテキストを控える。これらは毎周回シグナルから再計算される一過性のもので、
# BACKLOG に焼き付けると (a) 次周回に signal と BACKLOG の双方から二重出力され、
# (b) シグナル解消後（gate 緑化・TODO=0 等）も古い値のまま「ゾンビ」として残る。
# よって step 5 の BACKLOG 永続化では、これらのテキストを除外する。
cut -f6- "$raw" 2>/dev/null | sort -u > "$MAPE_STATE_DIR/.signal_texts"

# --- 2. BACKLOG.md「## 候補」の未チェック項目を取り込む ---
if [ -f "$MAPE_BACKLOG" ]; then
  while IFS= read -r line; do
    # prio/tier は必ず行頭プレフィックス `- [ ] (P?, tier)` から抽出する。
    # 全体を grep -oE で走査すると、本文に ASCII の `(P1` や `, word)` が含まれるとき
    # 多重マッチして $prio/$tier が複数行になり、tier が emit 内の case 正規化(65行)をすり抜けて
    # 人間が付けた consult がサイレントに approve へ降格する（安全境界の侵食）。
    prio=$(printf '%s' "$line" | sed -E 's/^- \[[ xX]\] \((P[0-9]), [a-z]+\).*/\1/')
    tier=$(printf '%s' "$line" | sed -E 's/^- \[[ xX]\] \(P[0-9], ([a-z]+)\).*/\1/')
    text=$(printf '%s' "$line" | sed -E 's/^- \[[ xX]\] \(P[0-9], [a-z]+\)[[:space:]]*//')
    [ -z "$prio" ] && prio=P3
    [ -z "$tier" ] && tier=approve
    [ -z "$text" ] && continue
    # 隔離（## ブロック中）済み候補は再提案しない（毒項目の全停止化を防ぐ自己修復。ADR-0015）。
    # → Execute が二度と拾わないので、同一項目ブレーカーが再発火せず status も ok に戻る。
    if mape_is_quarantined "$text"; then continue; fi
    # シグナル由来提案とテキストが完全一致する BACKLOG 項目は取り込まない（proposals.tsv への
    # 二重掲示防止）。step5 の永続化(下)には同じガードがあるが取り込み側に無いと、churn 首位が
    # BACKLOG 常設の churn 項目（例「変更集中箇所 …」）と一致したとき提案が2件出て、plan が
    # スコア違いの同一項目を二重にチェックリスト化する。永続化ガード(.signal_texts)と対称にする。
    if grep -qxF -- "$text" "$MAPE_STATE_DIR/.signal_texts" 2>/dev/null; then continue; fi
    case "$prio" in P1) impact=5;; P2) impact=3;; *) impact=2;; esac
    # 台帳メモリ（生きた核。ADR-0014）: 自分の過去の結果を読み、同じ失敗を繰り返さない。
    # done（実装済み=green あり）→ 再提案しない（板をスリムに保つ。ADR-0011）。
    # failing（慢性赤）→ impact を最小化して板の下位へ沈める（tier は不変＝安全境界を侵さない）。
    # BACKLOG 取り込み時のみ適用（シグナル由来はライブ値なので step1 では適用しない）。
    lstat=$(mape_ledger_status "$text")
    [ "$lstat" = done ] && continue
    [ "$lstat" = failing ] && impact=1
    emit "$tier" "$prio" "$impact" 3 "$text"
  done < <(grep -E '^- \[ \] \(P[0-9], [a-z]+\)' "$MAPE_BACKLOG" 2>/dev/null)
fi

# --- 3. スコア降順で proposals.tsv を確定 ---
sort -t$'\t' -k5,5nr "$raw" > "$MAPE_STATE_DIR/proposals.tsv"
n=$(wc -l < "$MAPE_STATE_DIR/proposals.tsv" | tr -d ' ')
nskip=$(grep -c . "$skipped" 2>/dev/null || true); nskip=${nskip:-0}

# --- 4. analysis.md（人が読む） ---
{
  echo "# Analyze レポート — ${MAPE_TS:-?} (cycle ${MAPE_CYCLE:-?})"
  echo
  echo "## 症状（Monitor シグナルの解釈）"
  echo
  echo "- 品質ゲート: ${MAPE_GATE:-skip}（${MAPE_GATE_S:-?} s）"
  echo "- 未完了マーカー TODO/FIXME: ${MAPE_TODO:-?} 件"
  echo "- 最長 SKILL.md: ${MAPE_MAX_SKILL:-?}/500 行 / CLAUDE.md: ${MAPE_CLAUDE_MD:-?}/200 行"
  echo "- churn 首位: ${MAPE_CHURN_TOP:-?}"
  echo
  echo "## 改善案（スコア = インパクト×(6-労力)、降順）"
  echo
  echo "| # | tier | prio | impact | effort | score | 内容（根拠つき） |"
  echo "|---|---|---|---|---|---|---|"
  i=0
  while IFS=$'\t' read -r tier prio impact effort score text; do
    i=$((i+1))
    echo "| $i | $tier | $prio | $impact | $effort | $score | $text |"
  done < "$MAPE_STATE_DIR/proposals.tsv"
  if [ "$nskip" -gt 0 ]; then
    echo
    echo "## 却下ログにより除外（POLICY.md）"
    echo
    while IFS= read -r t; do [ -n "$t" ] && echo "- $t"; done < "$skipped"
  fi
} > "$MAPE_STATE_DIR/analysis.md"

# --- 5. 新候補を BACKLOG へ（--update-knowledge のときだけ・重複回避） ---
if [ "$update_knowledge" -eq 1 ] && [ -f "$MAPE_BACKLOG" ]; then
  added=0
  while IFS=$'\t' read -r tier prio impact effort score text; do
    # シグナル由来（一過性）の提案は永続化しない（二重掲示・ゾンビ化の防止。step1 で控えたテキスト）
    if grep -qxF -- "$text" "$MAPE_STATE_DIR/.signal_texts" 2>/dev/null; then continue; fi
    # 既に BACKLOG 本文に含まれていれば追記しない（テキスト先頭40文字で判定）
    key=$(printf '%s' "$text" | cut -c1-40)
    if ! grep -qF -- "$key" "$MAPE_BACKLOG"; then
      # 「## アーカイブ」より前（＝候補セクション末尾）に挿入。アンカーが無ければ末尾に追記
      # （無ければ黙って捨てて「追記した」と誤報し、毎周回で再試行し続けるバグを防ぐ）。
      tmp=$(mktemp)
      awk -v ins="- [ ] ($prio, $tier) $text" '
        /^## アーカイブ/ && !done { print ins; print ""; done=1 }
        { print }
        END { if (!done) { print ""; print ins } }
      ' "$MAPE_BACKLOG" > "$tmp" && mv "$tmp" "$MAPE_BACKLOG"
      added=$((added+1))
    fi
  done < "$MAPE_STATE_DIR/proposals.tsv"
  mape_log "BACKLOG.md に新候補 $added 件を追記"
fi

mape_log "analyze 完了 → 提案 $n 件 / 除外 $nskip 件 → $MAPE_STATE_DIR/proposals.tsv"
