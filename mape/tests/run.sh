#!/usr/bin/env bash
# MAPE-K の自己テスト（決定論部分の回帰防止）。scripts/check.sh から呼ばれる。ADR-0010。
#
# 隔離: $MAPE_STATE_DIR を一時ディレクトリに向け、knowledge/ は読み取りのみ。
# 注意: monitor は --with-gate を付けない（check.sh 経由の再帰を避ける）。
#
# トレーサビリティ（docs/requirements/mape-k.md）:
#   Verifies: REQ-MAPE-001  Verifies: REQ-MAPE-002  Verifies: REQ-MAPE-003  Verifies: REQ-MAPE-004
#   Verifies: NFR-PERF-001  Verifies: NFR-REL-001   Verifies: NFR-SEC-001   Verifies: NFR-OPT-001
#   Verifies: NFR-MNT-001   Verifies: NFR-OPS-001   Verifies: NFR-SAFE-001  Verifies: NFR-SAFE-002
set -u

# 再帰ガード: このテストは monitor/run を呼ぶ。monitor の --with-gate が check.sh を回すと
# （check.sh → このテスト → monitor → check.sh …）無限再帰になるため、ゲート実行を抑止する。
export MAPE_NO_GATE=1

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAPE_DIR="$(cd "$TESTS_DIR/.." && pwd)"
REPO="$(cd "$MAPE_DIR/.." && pwd)"
cd "$REPO" || exit 1

pass=0; fail=0
ok()  { echo "  ok: $*"; pass=$((pass+1)); }
ng()  { echo "  NG: $*" >&2; fail=$((fail+1)); }
sec() { echo "== $* =="; }

# 隔離した state ディレクトリ（テストは knowledge/ を変更しない）
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export MAPE_STATE_DIR="$TMP/state"

# ---------------------------------------------------------------------------
sec "0. 構文（bash -n）— NFR-MNT-001"
for f in "$MAPE_DIR"/*.sh "$TESTS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  rel="${f#"$REPO"/}"
  if bash -n "$f" 2>/dev/null; then ok "syntax $rel"; else ng "syntax $rel"; fi
done

# lib を読み込んで関数を直接テスト
# shellcheck source=/dev/null
. "$MAPE_DIR/lib.sh"

# ---------------------------------------------------------------------------
sec "1. Monitor は読み取り専用でシグナルを出す — REQ-MAPE-001 / NFR-PERF-001"
health_before="$(cksum "$MAPE_HEALTH" 2>/dev/null)"
bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
health_after="$(cksum "$MAPE_HEALTH" 2>/dev/null)"
[ -f "$MAPE_STATE_DIR/monitor.env" ] && ok "monitor.env 生成" || ng "monitor.env が無い"
missing=""
for k in MAPE_GATE MAPE_TODO MAPE_SCRIPTS MAPE_MAX_SKILL MAPE_CLAUDE_MD MAPE_ADR; do
  grep -q "^$k=" "$MAPE_STATE_DIR/monitor.env" || missing="$missing $k"
done
[ -z "$missing" ] && ok "必須キーが揃う" || ng "monitor.env に欠落:$missing"
[ "$health_before" = "$health_after" ] && ok "--record 無しは HEALTH.md を変更しない" || ng "read-only 違反: HEALTH.md が変わった"

# ---------------------------------------------------------------------------
sec "2. Analyze は根拠つき提案をスコア降順で出す — REQ-MAPE-002"
bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
[ -s "$tsv" ] && ok "proposals.tsv 生成（非空）" || ng "proposals.tsv が空"
# 5列目(score)が非増加か
if awk -F'\t' 'NR>1 && $5>prev{bad=1} {prev=$5} END{exit bad?1:0}' "$tsv"; then
  ok "スコア降順に整列"
else
  ng "スコアが降順でない"
fi
# 却下フィルタ（関数単体）
if mape_is_rejected "大規模な全面書き換えをする"; then ok "却下ログでフィルタされる"; else ng "却下フィルタが効かない"; fi

# ---------------------------------------------------------------------------
sec "3. Plan はリスク3分類チェックリストを出す — REQ-MAPE-003"
bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
body="$MAPE_STATE_DIR/issue-body.md"
for h in "## ✅ 自動" "## 🟡 承認" "## 🔴 相談"; do
  grep -qF "$h" "$body" && ok "セクション: $h" || ng "セクション欠落: $h"
done
grep -qE '^- \[x\] ' "$body" && ok "自動項目は既定チェック済み[x]" || ng "自動項目に[x]が無い"
grep -qE '^- \[ \] ' "$body" && ok "承認/相談は未チェック[ ]あり" || ng "未チェック項目が無い"

# ---------------------------------------------------------------------------
sec "4. Execute のガードレール: 緑→記録 / 赤→記録・冪等 — REQ-MAPE-004 / NFR-OPS-001"
cb="$MAPE_DIR/circuit-breaker.sh"
bash "$cb" record green "項目X" 42 mape/exec-x >/dev/null 2>&1
# jq(コンパクト)と python3(コロン後に空白)の双方の JSON 整形を許容する（` *` でコロン後の空白を吸収）
grep -Eq '"result": *"green"' "$MAPE_STATE_DIR/ledger.jsonl" && ok "green を台帳へ記録" || ng "green 記録失敗"
grep -Eq '"pr": *"42"' "$MAPE_STATE_DIR/ledger.jsonl" && ok "PR番号を記録" || ng "PR番号記録失敗"
if bash "$cb" done "項目X" >/dev/null 2>&1; then ok "done: 実装済み項目を検出（冪等性）"; else ng "done 判定失敗"; fi
if bash "$cb" done "未着手項目" >/dev/null 2>&1; then ng "done: 未着手を済みと誤判定"; else ok "done: 未着手は未実装と判定"; fi
bash "$cb" record red "項目Y" >/dev/null 2>&1
grep -Eq '"result": *"red"' "$MAPE_STATE_DIR/ledger.jsonl" && ok "red を台帳へ記録" || ng "red 記録失敗"

# ---------------------------------------------------------------------------
sec "5. サーキットブレーカーが連鎖失敗で停止する — NFR-REL-001"
rm -f "$MAPE_STATE_DIR/ledger.jsonl"
bash "$cb" status >/dev/null 2>&1 && ok "空台帳は ok(exit0)" || ng "空台帳で停止した"
bash "$cb" record red "同一項目" >/dev/null 2>&1
bash "$cb" record red "同一項目" >/dev/null 2>&1
if bash "$cb" status >/dev/null 2>&1; then ng "同一項目 red 2回で停止しない"; else ok "同一項目 red 2回で tripped(exit3)"; fi
bash "$cb" reset >/dev/null 2>&1
bash "$cb" record green "別項目" >/dev/null 2>&1
bash "$cb" status >/dev/null 2>&1 && ok "reset 後は ok に戻る" || ng "reset 後も停止のまま"

# ---------------------------------------------------------------------------
sec "6. リスク分類は危険側優先（consult） — NFR-SEC-001"
[ "$(mape_classify '認証フローを追加する')" = "consult" ] && ok "認証→consult" || ng "認証が consult にならない"
[ "$(mape_classify '課金APIを叩く')" = "consult" ] && ok "課金→consult" || ng "課金が consult にならない"
[ "$(mape_classify 'テスト追加する')" = "auto" ] && ok "テスト追加→auto" || ng "テスト追加が auto にならない"
[ "$(mape_classify '謎の変更')" = "approve" ] && ok "既定→approve（安全側）" || ng "既定が approve でない"

# ---------------------------------------------------------------------------
sec "7. knowledge/ の機械可読構造が保たれる — NFR-MNT-001"
grep -qF '| ts(UTC) | cycle | gate | gate_s | todo | scripts | max_skill | claude_md | adr | note |' "$MAPE_HEALTH" \
  && ok "HEALTH 推移表ヘッダあり" || ng "HEALTH 推移表ヘッダが変わっている"
for h in '### consult' '### approve' '### auto'; do
  grep -qF "$h" "$MAPE_POLICY" && ok "POLICY 見出し: $h" || ng "POLICY 見出し欠落: $h"
done

# ---------------------------------------------------------------------------
sec "8. Plan はガードレール footer を掲示に含める — REQ-MAPE-003"
grep -qF "### 使い方 / ガードレール" "$body" && ok "ガードレール見出しあり" || ng "ガードレール見出しが無い"
grep -qF "1周1件" "$body" && ok "1周1件の明記あり" || ng "1周1件の明記が無い"

# ---------------------------------------------------------------------------
sec "9. run.sh のドライランは knowledge/ を一切変更しない — NFR-PERF-001"
snap_before="$(cat <(cksum "$MAPE_HEALTH") <(cksum "$MAPE_BACKLOG") <(cksum "$MAPE_PROGRESS") 2>/dev/null)"
bash "$MAPE_DIR/run.sh" >/dev/null 2>&1   # フラグ無し = ドライラン
snap_after="$(cat <(cksum "$MAPE_HEALTH") <(cksum "$MAPE_BACKLOG") <(cksum "$MAPE_PROGRESS") 2>/dev/null)"
[ "$snap_before" = "$snap_after" ] && ok "run.sh ドライランは HEALTH/BACKLOG/PROGRESS を変更しない" || ng "ドライランが knowledge を変更した"

# ---------------------------------------------------------------------------
sec "10. スコアは高インパクト・低労力ほど高い — REQ-MAPE-002"
s_hi=$(mape_score 5 2); s_lo=$(mape_score 3 3)
[ "$s_hi" -gt "$s_lo" ] && ok "score(5,2)=$s_hi > score(3,3)=$s_lo" || ng "スコアの大小が逆転"
[ "$(mape_score 5 1)" -eq 25 ] && ok "score 上限=25" || ng "score 上限が 25 でない"

# ---------------------------------------------------------------------------
sec "11. Plan は完了ログを台帳から畳んで掲示する（green のみ） — REQ-MAPE-003（ADR-0011）"
# 合成台帳（green 2 / red 1）で plan を生成し、完了ログ <details> を検証
printf '%s\n' \
  '{"ts":"t1","item":"完了A","result":"green","pr":"5","branch":"b"}' \
  '{"ts":"t2","item":"完了B","result":"green","pr":"7","branch":"b"}' \
  '{"ts":"t3","item":"失敗C","result":"red","pr":"","branch":"b"}' > "$MAPE_STATE_DIR/ledger.jsonl"
bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
grep -qF '<summary>✅ 完了ログ（2 件' "$body"     && ok "完了ログの件数=green数(2)" || ng "完了ログ件数が合わない"
grep -qF '完了A → PR #5'  "$body"                  && ok "green を完了ログに掲示" || ng "green が完了ログに無い"
grep -qF '失敗C' "$body"                            && ng "red を完了ログに載せてはいけない" || ok "red は完了ログに載せない"
rm -f "$MAPE_STATE_DIR/ledger.jsonl"
bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
grep -qF '完了ログ（0 件' "$body" && ok "台帳が空でも完了ログ0件で壊れない" || ng "空台帳で完了ログが壊れる"

# ---------------------------------------------------------------------------
sec "12. monitor.env はコマンド注入を実行しない（source しない） — NFR-SEC-001（ADR-0011 R2-1）"
# 敵対的な churn 由来値を模した monitor.env を作り、analyze が load しても任意コマンドが走らないこと
pwned="$MAPE_STATE_DIR/PWNED"
rm -f "$pwned"
{
  echo "MAPE_TS=2026-01-01T00:00Z"
  echo "MAPE_CYCLE=1"
  echo "MAPE_GATE=skip"
  echo "MAPE_GATE_S=-"
  echo "MAPE_TODO=0"
  echo "MAPE_SCRIPTS=1"
  echo "MAPE_MAX_SKILL=1"
  echo "MAPE_CLAUDE_MD=1"
  echo "MAPE_ADR=1"
  echo "MAPE_CHURN_TOP=x\$(touch $pwned);\`touch $pwned\`"
} > "$MAPE_STATE_DIR/monitor.env"
bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
[ ! -e "$pwned" ] && ok "注入ペイロードは実行されない（source 廃止）" || { ng "注入ペイロードが実行された"; rm -f "$pwned"; }
# 値はリテラルとして読めていること（load して変数に入る）
# shellcheck source=/dev/null
. "$MAPE_DIR/lib.sh"
mape_load_env "$MAPE_STATE_DIR/monitor.env"
[ -n "${MAPE_CHURN_TOP:-}" ] && ok "許可キーはリテラルで読める" || ng "mape_load_env が値を読めない"

# ---------------------------------------------------------------------------
sec "13. 台帳の破損行に耐える — NFR-REL-001（バグハント回帰）"
# circuit-breaker done: 不正行があっても green 済み項目を検出できる（jq ストリーム中断バグ）
cbL="$MAPE_STATE_DIR/ledger.jsonl"
printf '%s\n' '{"item":"AA","result":"green","pr":"1"}' 'BROKEN{' > "$cbL"
bash "$cb" done "AA" >/dev/null 2>&1 && ok "done: 不正行があっても green を検出" || ng "done が不正行で誤判定"
bash "$cb" done "ZZ" >/dev/null 2>&1 && ng "done: 未登録を済みと誤判定" || ok "done: 未登録は未実装"
# plan done_log: 不正行（構文破損・非オブジェクト）があっても以降の green を落とさない。
# 注意: `→ PR #[0-9]` で数える（plan フッタの説明文 `→ PR #N` を数えないため。旧テストは
# フッタ1件を足し込み、CC を落としても dn=2 で誤って緑になっていた＝false-green の是正。[26]）
printf '%s\n' '{"item":"AA","result":"green","pr":"1","ts":"t"}' 'BROKEN{' '123' '{"item":"CC","result":"green","pr":"3","ts":"t"}' > "$cbL"
bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
dn=$(grep -c '→ PR #[0-9]' "$body")
[ "$dn" -eq 2 ] && ok "完了ログは不正行/非オブジェクト後の green も残す（jq経路・$dn 件）" || ng "完了ログが不正行で green を落とす（jq・$dn 件）"
if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  sbjq2="$TMP/sbjq2"; mkbin() { local bin="$1"; shift; local hide=" $* " d f n oi; rm -rf "$bin"; mkdir -p "$bin"; oi=$IFS; IFS=:; for d in $PATH; do [ -d "$d" ] || continue; for f in "$d"/*; do [ -x "$f" ] || continue; n=$(basename "$f"); case "$hide" in *" $n "*) continue;; esac; [ -e "$bin/$n" ] || ln -s "$f" "$bin/$n" 2>/dev/null; done; done; IFS=$oi; }
  mkbin "$sbjq2" jq
  PATH="$sbjq2" MAPE_STATE_DIR="$MAPE_STATE_DIR" bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
  dn2=$(grep -c '→ PR #[0-9]' "$body")
  [ "$dn2" -eq 2 ] && ok "完了ログは不正行後の green も残す（python3経路・$dn2 件）" || ng "完了ログが python3経路で green を落とす（$dn2 件）"
  rm -rf "$sbjq2"
fi
rm -f "$cbL"

# ---------------------------------------------------------------------------
sec "14. ロケール/正規化の回帰（バグハント）"
# em-dash を含む却下パターンが安全な提案を誤却下しない（[^—] ロケール誤爆）
tmpk=$(mktemp -d); cp "$MAPE_POLICY" "$tmpk/POLICY.md"
printf '%s\n' '- pattern: churn 首位…限定 — 却下理由' >> "$tmpk/POLICY.md"
( MAPE_POLICY="$tmpk/POLICY.md"; mape_is_rejected "churn 首位 README.md のテスト強化" ) \
  && ng "em-dash: 安全な提案を誤却下" || ok "em-dash: 安全な提案を誤却下しない"
( MAPE_POLICY="$tmpk/POLICY.md"; mape_is_rejected "大規模な全面書き換えをする" ) \
  && ok "既存の却下パターンは機能する" || ng "既存の却下パターンが効かない"
rm -rf "$tmpk"
# mape_score は effort>5 でも負にならない（上限クランプ）
[ "$(mape_score 5 10)" -eq "$(mape_score 5 3)" ] && ok "score: effort>5 はクランプ（負値なし）" || ng "score: effort>5 で負値"

# ---------------------------------------------------------------------------
sec "15. analyze/plan の知識取り込み回帰（バグハント）"
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$tk/"
# tier タイポ正規化: plan は auto/approve/consult のみ描画するため未知 tier は approve へ
printf '# B\n## 候補\n- [ ] (P2, aprove) タイポtier重要提案 — t\n- [ ] (P2, approve) 正しい提案 — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
grep -qF 'タイポtier重要提案' "$body" && ok "未知 tier の項目も計画本文に出る（黙って消えない）" || ng "未知 tier の項目が計画本文から消える"
# シグナル由来（一過性）の提案は BACKLOG に永続化しない（二重掲示・ゾンビ化の防止。R3-1）
printf '# B\n## 候補\n- [ ] (P2, approve) 既存 — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
b0=$(wc -l < "$tk/BACKLOG.md")
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" --update-knowledge >/dev/null 2>&1
b1=$(wc -l < "$tk/BACKLOG.md")
[ "$b1" -eq "$b0" ] && ok "シグナル由来提案は BACKLOG に永続化しない（$b0→$b1）" || ng "シグナル由来提案が BACKLOG を肥大させる"
# 解消済みシグナル（gate=fail→pass）がゾンビとして残らない
printf 'MAPE_GATE=fail\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" --update-knowledge >/dev/null 2>&1
grep -qF '赤を直す' "$tk/BACKLOG.md" && ng "解消可能なシグナル提案が BACKLOG に焼き付く（ゾンビ）" || ok "gate=fail 提案は BACKLOG に焼き付かない"
# tier 抽出は行頭プレフィックス固定: 本文に ASCII の `, word)` があっても
# 人間が付けた consult が approve へサイレント降格しない（安全境界の侵食・R5）。
# ※本文は consult キーワードを含めない（含めると classify が救済して抽出バグを隠す）
printf '# B\n## 候補\n- [ ] (P2, consult) 余白を (a, b) に調整する — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tline=$(grep -F '余白を (a, b)' "$MAPE_STATE_DIR/proposals.tsv" | cut -f1)
[ "$tline" = "consult" ] && ok "本文の ASCII 括弧があっても consult tier を保つ（$tline）" || ng "consult が $tline へサイレント降格（tier 抽出が本文を誤読）"
# シグナル由来提案と完全一致する BACKLOG 項目は proposals.tsv に二重掲示しない（取り込み側 dedup。R9）
# churn 首位のシグナル文と同一テキストの BACKLOG 常設項目を置き、提案が1件になることを確認する。
churn_text='変更集中箇所 scripts/check.sh のテスト強化/整理を検討 — 根拠: 直近30コミットの churn 首位 / 回帰リスク'
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=scripts/check.sh\n' > "$MAPE_STATE_DIR/monitor.env"
printf '# B\n## 候補\n- [ ] (P3, approve) %s\n## アーカイブ\n' "$churn_text" > "$tk/BACKLOG.md"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
dup=$(grep -cF "$churn_text" "$MAPE_STATE_DIR/proposals.tsv" 2>/dev/null || true); dup=${dup:-0}
[ "$dup" -eq 1 ] && ok "シグナルと同一テキストのBACKLOG項目は二重掲示しない（${dup}件）" || ng "シグナル×BACKLOGで同一提案が二重掲示（${dup}件）"
rm -rf "$tk"

# ---------------------------------------------------------------------------
sec "16. churn は自分の帳簿（knowledge/・mape/state/）を首位にしない（バグハント回帰）"
bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
ctop=$(grep '^MAPE_CHURN_TOP=' "$MAPE_STATE_DIR/monitor.env" | cut -d= -f2-)
case "$ctop" in
  knowledge/*|mape/state/*) ng "churn 首位が帳簿ファイル: $ctop" ;;
  *) ok "churn 首位は帳簿ファイルでない（$ctop）" ;;
esac

# ---------------------------------------------------------------------------
sec "17. circuit-breaker status は破損台帳でもクラッシュしない（python/jq 両経路） — NFR-REL-001（R4/R5）"
cbS="$MAPE_STATE_DIR/ledger.jsonl"
printf 'BROKEN{\nnot json\n' > "$cbS"   # 有効行0件（全行不正）
bash "$cb" status >/dev/null 2>&1; [ $? -eq 0 ] && ok "破損台帳(全行不正)で ok(0)＝誤発火しない（python 経路）" || ng "破損台帳で誤発火/異常終了"
# jq フォールバック経路（python3 を隠した完全 sandbox。jq がある時のみ）
if command -v jq >/dev/null 2>&1; then
  sb=$(mktemp -d); oifs=$IFS; IFS=:
  for d in $PATH; do [ -d "$d" ] || continue; for f in "$d"/*; do [ -x "$f" ] || continue; bn=$(basename "$f"); [ "$bn" = python3 ] && continue; [ -e "$sb/$bn" ] || ln -s "$f" "$sb/$bn" 2>/dev/null; done; done
  IFS=$oifs
  printf 'BROKEN{\nnot json\n' > "$cbS"
  MAPE_STATE_DIR="$MAPE_STATE_DIR" PATH="$sb" bash "$cb" status >/dev/null 2>&1
  [ $? -eq 0 ] && ok "jq フォールバック: 破損台帳(0有効行)でクラッシュしない" || ng "jq フォールバックが破損台帳でクラッシュ"
  printf '{"item":"A","result":"red"}\n{"item":"A","result":"red"}\nBAD{\n' > "$cbS"
  MAPE_STATE_DIR="$MAPE_STATE_DIR" PATH="$sb" bash "$cb" status >/dev/null 2>&1
  [ $? -eq 3 ] && ok "jq フォールバック: 破損混在でも正しく tripped" || ng "jq フォールバックの停止判定が誤り"
  rm -rf "$sb"
fi
rm -f "$cbS"

# ---------------------------------------------------------------------------
sec "18. 外部制御シグナルの無毒化（計画イシュー/無人 Execute への注入遮断） — NFR-SEC-001"
# 18a. 純粋関数 mape_sanitize_signal（test-first。ADR-0013）— 厳密一致で未実装を確実に赤にする
[ "$(mape_sanitize_signal 'scripts/check_v2.sh')" = 'scripts/check_v2.sh' ] \
  && ok "sanitize: 正当なファイル名は温存" || ng "sanitize: 正当名を壊す/未実装"
got=$(mape_sanitize_signal 'a`b[c]d<e>f|g\h')
[ "$got" = 'abcdefgh' ] && ok "sanitize: md/html 危険メタ文字を除去（$got）" || ng "sanitize: メタ文字除去が不正（$got）"
nl=$(mape_sanitize_signal "$(printf 'x\ny')")
[ "$nl" = 'x y' ] && ok "sanitize: 改行を空白へ（複数行注入を潰す）" || ng "sanitize: 改行が残る（$nl）"
ln=$(mape_sanitize_signal "$(printf 'a%.0s' $(seq 1 200))")
[ "${#ln}" -eq 80 ] && ok "sanitize: 80字に丸める（${#ln}）" || ng "sanitize: 長さ制限なし（${#ln}）"
# 18c. マルチバイト（日本語）を長さ丸めで割らない（HEALTH note 列・Execute プロンプトへ不正UTF-8を出さない。回帰）
# C locale（bare cron 既定）で再現する: bash の ${s:0:80} が C ではバイト単位＝多バイト文字を割る。
if command -v iconv >/dev/null 2>&1; then
  jp=$(printf 'あ%.0s' $(seq 1 100))
  mb=$(LC_ALL=C IN="$jp" bash -c '. "'"$MAPE_DIR"'/lib.sh"; mape_sanitize_signal "$IN"')
  printf '%s' "$mb" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && ok "sanitize: マルチバイトを割らず有効なUTF-8（C locale）" || ng "sanitize: マルチバイト境界で不正UTF-8"
  [ "$(printf '%s' "$mb" | wc -c)" -le 80 ] && ok "sanitize: マルチバイトでも80バイト以内" || ng "sanitize: 80バイト超過"
  # [3] UTF-8 ロケール（C.UTF-8＝cron/systemd 既定になりうる）でも 80 バイト契約を守る。
  # 旧 ${s:0:80} は UTF-8 ロケールで文字単位に切り、日本語で最大 ~240 バイトに膨張していた。
  mbu=$(LANG=C.UTF-8 LC_ALL=C.UTF-8 IN="$jp" bash -c '. "'"$MAPE_DIR"'/lib.sh"; mape_sanitize_signal "$IN"' 2>/dev/null)
  [ -n "$mbu" ] && [ "$(printf '%s' "$mbu" | wc -c)" -le 80 ] && ok "sanitize: UTF-8 ロケールでも80バイト以内（byte cap・[3]）" || ng "sanitize: UTF-8 ロケールで80バイト超過（文字単位切り）"
  rr2=$(LC_ALL=C IN='knowledge 整合性 NG（DNA 破損）; 作業ツリーに未コミット変更あり' bash -c '. "'"$MAPE_DIR"'/lib.sh"; mape_sanitize_signal "$IN"')
  printf '%s' "$rr2" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && ok "sanitize: 日本語 safe-state 理由も有効なUTF-8" || ng "sanitize: 日本語理由で不正UTF-8"
fi
# 18b. 統合: 悪意ある churn を仕込んだ monitor.env → analyze → plan で issue-body に注入が残らない
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$MAPE_BACKLOG" "$MAPE_PROGRESS" "$tk/" 2>/dev/null
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=`evil`](x) <i>|col\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/plan.sh" >/dev/null 2>&1
if grep -qE '`evil`|\]\(x\)|<i>' "$body" 2>/dev/null; then
  ng "統合: churn 由来の注入が issue-body に残存"
else
  ok "統合: churn 由来の注入が issue-body に残らない"
fi
rm -rf "$tk"

# ---------------------------------------------------------------------------
sec "19. 記憶を持つ Analyze: 台帳(ledger)の結果を読む（生きた核。ADR-0014） — REQ-MAPE-002"
# 19a. 純粋関数 mape_ledger_status（test-first。ADR-0013）— 厳密一致で未実装を確実に赤にする
lg="$MAPE_STATE_DIR/ledger.jsonl"
{ printf '{"ts":"t","item":"DONE_X","result":"green","pr":"1","branch":"b"}\n'
  printf '{"ts":"t","item":"FAIL_Y","result":"red","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"FAIL_Y","result":"red","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"ONE_Z","result":"red","pr":"","branch":""}\n'; } > "$lg"
[ "$(mape_ledger_status 'DONE_X')" = done ] && ok "ledger: green は done" || ng "ledger: green を done にしない"
[ "$(mape_ledger_status 'FAIL_Y')" = failing ] && ok "ledger: red×2 は failing" || ng "ledger: 慢性赤を failing にしない"
[ -z "$(mape_ledger_status 'ONE_Z')" ] && ok "ledger: red×1 は閾値未満で無印" || ng "ledger: red×1 を誤って failing"
[ -z "$(mape_ledger_status 'NOPE')" ] && ok "ledger: 未登録は無印" || ng "ledger: 未登録を誤判定"
# 破損行が混ざっても中断せず有効行を集計する（jq ストリーム中断/py 例外への耐性。バグハント教訓）
{ printf 'BROKEN{\n'; printf '{"ts":"t","item":"DONE_X","result":"green"}\n'; printf 'not json\n'; } > "$lg"
[ "$(mape_ledger_status 'DONE_X')" = done ] && ok "ledger: 破損行混在でも有効な green を検出" || ng "ledger: 破損行で集計が中断"
rm -f "$lg"
# 19b. 統合: BACKLOG 取り込みで done はスキップ・failing は降格・シグナルは免疫
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$tk/" 2>/dev/null
printf '# B\n## 候補\n- [ ] (P2, approve) 項目A 実装済のはず — t\n- [ ] (P2, approve) 項目B 慢性的に赤 — t\n- [ ] (P2, approve) 項目C 新規 — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
gatetext='品質ゲート（scripts/check.sh）の赤を直す — 根拠: gate=fail（最優先。緑化するまで他を止める）'
{ printf '{"ts":"t","item":"項目A 実装済のはず — t","result":"green","pr":"9","branch":"b"}\n'
  printf '{"ts":"t","item":"項目B 慢性的に赤 — t","result":"red","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"項目B 慢性的に赤 — t","result":"red","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"%s","result":"green","pr":"1","branch":"b"}\n' "$gatetext"; } > "$MAPE_STATE_DIR/ledger.jsonl"
printf 'MAPE_GATE=fail\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
grep -qF '項目A' "$tsv" && ng "ledger memory: 実装済(green)を再提案してしまう" || ok "ledger memory: 実装済(green)は再提案しない"
grep -qF '項目C' "$tsv" && ok "ledger memory: 新規項目は通常提案" || ng "ledger memory: 新規項目が消えた"
bsc=$(grep -F '項目B' "$tsv" | cut -f5); csc=$(grep -F '項目C' "$tsv" | cut -f5)
{ [ -n "$bsc" ] && [ -n "$csc" ] && [ "$bsc" -lt "$csc" ]; } 2>/dev/null \
  && ok "ledger memory: 慢性赤(B)を新規(C)より低スコアへ降格（$bsc<$csc）" || ng "ledger memory: 慢性赤が降格されない（B=$bsc C=$csc）"
grep -qF '品質ゲート' "$tsv" && ok "ledger memory: シグナル提案は過去 green で抑制されない（現状を反映）" || ng "ledger memory: シグナル提案が過去 green で誤抑制"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "20. 恒常性: POLICY の健全性バンド(setpoint)で逸脱幅に応じ提案（ADR-0014） — REQ-MAPE-002"
# 20a. 純粋関数 mape_band_status（test-first。ADR-0013）
spw="$TMP/pol_with.md"; printf '### 健全性バンド（setpoints）\n```\ngate_s 10 20\n```\n' > "$spw"
spn="$TMP/pol_no.md"; printf '# setpoints 無し\n' > "$spn"
[ "$(MAPE_POLICY="$spw" mape_band_status gate_s 12)" = warn ] && ok "band: POLICY setpoint を優先(warn)" || ng "band: POLICY setpoint を読まない/未実装"
[ "$(MAPE_POLICY="$spw" mape_band_status gate_s 25)" = crit ] && ok "band: crit 判定" || ng "band: crit 判定が不正"
[ "$(MAPE_POLICY="$spw" mape_band_status gate_s 5)"  = ok ]   && ok "band: warn 未満は ok" || ng "band: ok 判定が不正"
[ "$(MAPE_POLICY="$spn" mape_band_status claude_md 192)" = warn ] && ok "band: block 無しは baked 既定(claude_md warn=190)" || ng "band: 既定フォールバックが不正"
[ "$(MAPE_POLICY="$spn" mape_band_status gate_s -)" = ok ] && ok "band: 非数値(-)は判定せず ok" || ng "band: 非数値を誤判定"
# [5/7/16] 壊れた setpoint（crit 欠落）は crit を warn に誤降格せず、契約どおり ok（フェイルセーフ）へ倒す
sp1="$TMP/pol_warn_only.md"; printf '### 健全性バンド（setpoints）\n```\ntodo 5\n```\n' > "$sp1"
[ "$(MAPE_POLICY="$sp1" mape_band_status todo 100)" = ok ] && ok "band: crit 欠落の setpoint は ok へフェイルセーフ（誤って warn/crit にしない）" || ng "band: crit 欠落で誤判定（過小報告/フェイルセーフ違反）"
# 20b. 統合: gate_s 逸脱（従来は無反応）が提案化し crit は P1、claude_md warn も提案化
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$tk/" 2>/dev/null
printf '# B\n## 候補\n## アーカイブ\n' > "$tk/BACKLOG.md"
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=40\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=192\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\n' > "$MAPE_STATE_DIR/monitor.env"
: > "$MAPE_STATE_DIR/ledger.jsonl"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
grep -qF 'gate_s' "$tsv" && ok "homeostasis: gate_s 逸脱が提案化（従来は無反応）" || ng "homeostasis: gate_s が監視されない"
[ "$(awk -F'\t' '/gate_s/{print $2; exit}' "$tsv")" = P1 ] && ok "homeostasis: crit は P1 へ昇格" || ng "homeostasis: crit の優先度が不正"
grep -qF 'CLAUDE.md を予算内' "$tsv" && ok "homeostasis: claude_md warn が提案化" || ng "homeostasis: claude_md warn が出ない"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "21. 知識ファイルの機械可読不変条件を検証する（DNA 完全性・fail-closed。ADR-0014） — NFR-MNT-001"
kv=$(mktemp -d)
cp "$MAPE_HEALTH" "$kv/HEALTH.md"; cp "$MAPE_POLICY" "$kv/POLICY.md"; cp "$MAPE_BACKLOG" "$kv/BACKLOG.md"
( MAPE_HEALTH="$kv/HEALTH.md" MAPE_POLICY="$kv/POLICY.md" MAPE_BACKLOG="$kv/BACKLOG.md" MAPE_STATE_DIR="$kv/nostate" mape_verify_knowledge ) 2>/dev/null \
  && ok "健全な知識ファイルは 0（合格）" || ng "健全なのに非0/未実装"
hb="$kv/health_bad.md"; cp "$MAPE_HEALTH" "$hb"; printf '%s\n' '| 2026-01-01T00:00Z | 1 | pass |' >> "$hb"
out=$( ( MAPE_HEALTH="$hb" MAPE_STATE_DIR="$kv/nostate" mape_verify_knowledge ) 2>&1 ); rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF HEALTH; } && ok "HEALTH 列数不一致を検出し名指し" || ng "HEALTH 破損を検出しない（rc=$rc）"
hh="$kv/health_nohdr.md"; grep -vF 'ts(UTC)' "$MAPE_HEALTH" > "$hh"
( MAPE_HEALTH="$hh" MAPE_STATE_DIR="$kv/nostate" mape_verify_knowledge ) 2>/dev/null && ng "HEALTH ヘッダ欠落を見逃す" || ok "HEALTH ヘッダ欠落を検出"
pb="$kv/policy_nohd.md"; grep -vF '### auto' "$MAPE_POLICY" > "$pb"
out=$( ( MAPE_POLICY="$pb" MAPE_STATE_DIR="$kv/nostate" mape_verify_knowledge ) 2>&1 ); rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF POLICY; } && ok "POLICY 見出し欠落を検出し名指し" || ng "POLICY 見出し欠落を見逃す（rc=$rc）"
pr="$kv/policy_badre.md"; cp "$MAPE_POLICY" "$pr"; printf '%s\n' '- pattern: [unterminated — 壊れた正規表現' >> "$pr"
out=$( ( MAPE_POLICY="$pr" MAPE_STATE_DIR="$kv/nostate" mape_verify_knowledge ) 2>&1 ); rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF POLICY; } && ok "POLICY 不正正規表現を検出し名指し" || ng "POLICY 不正正規表現を見逃す（rc=$rc）"
bb="$kv/backlog_bad.md"; grep -vF '## アーカイブ' "$MAPE_BACKLOG" > "$bb"
out=$( ( MAPE_BACKLOG="$bb" MAPE_STATE_DIR="$kv/nostate" mape_verify_knowledge ) 2>&1 ); rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF BACKLOG; } && ok "BACKLOG アンカー欠落を検出し名指し" || ng "BACKLOG アンカー欠落を見逃す（rc=$rc）"
ls="$kv/lstate"; mkdir -p "$ls"; printf '%s\n' 'BROKEN{' > "$ls/ledger.jsonl"
out=$( ( MAPE_STATE_DIR="$ls" mape_verify_knowledge ) 2>&1 ); rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF ledger; } && ok "ledger 破損行を検出し名指し" || ng "ledger 破損行を見逃す（rc=$rc）"
printf '%s\n' '{"ts":"t","item":"x"}' > "$ls/ledger.jsonl"
( MAPE_STATE_DIR="$ls" mape_verify_knowledge ) 2>/dev/null && ng "ledger 必須キー欠落を見逃す" || ok "ledger 必須キー欠落を検出"
printf '%s\n\n' '{"ts":"t","item":"x","result":"green"}' > "$ls/ledger.jsonl"
( MAPE_STATE_DIR="$ls" mape_verify_knowledge ) 2>/dev/null && ok "ledger 健全＋空行は許容（0）" || ng "健全 ledger を誤検出"
# [wave4] 空白のみの行（partial append 等）も「空行は許容」の契約どおり両バックエンドで許容し、
# インストール済みパーサでゲート verdict が食い違わない（決定論ゲート）。
printf '%s\n \t \n%s\n' '{"ts":"t","item":"x","result":"green"}' '{"ts":"t","item":"y","result":"green"}' > "$ls/ledger.jsonl"
( MAPE_STATE_DIR="$ls" mape_verify_knowledge ) 2>/dev/null && r_def=0 || r_def=1
if command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  sbw="$TMP/sbw"; rm -rf "$sbw"; mkdir -p "$sbw"; oi=$IFS; IFS=:
  for d in $PATH; do [ -d "$d" ] || continue; for f in "$d"/*; do [ -x "$f" ] || continue; n=$(basename "$f"); [ "$n" = jq ] && continue; [ -e "$sbw/$n" ] || ln -s "$f" "$sbw/$n" 2>/dev/null; done; done; IFS=$oi
  r_py=$(PATH="$sbw" bash -c '. "'"$MAPE_DIR"'/lib.sh"; MAPE_STATE_DIR="'"$ls"'" mape_verify_knowledge >/dev/null 2>&1; echo $?')
  { [ "$r_def" = 0 ] && [ "$r_py" = 0 ]; } && ok "ledger 空白のみ行を両経路で許容（決定論ゲート・def=$r_def py=$r_py）" || ng "ledger 空白のみ行でバックエンド verdict 相違（def=$r_def py=$r_py）"
  rm -rf "$sbw"
else
  [ "$r_def" = 0 ] && ok "ledger 空白のみ行を許容" || ng "ledger 空白のみ行を誤検出"
fi
rm -rf "$kv"

# ---------------------------------------------------------------------------
sec "23. 心拍/休眠自己検知（liveness。ADR-0014） — NFR-REL-001"
# 23a. 純粋関数 mape_epoch_utc（test-first。ADR-0013）
e0=$(mape_epoch_utc 2026-07-19T14:37Z)
[ "$e0" = 1784471820 ] && ok "epoch: 既知 ts を正しく変換" || ng "epoch: 変換値が誤り/未実装（$e0）"
{ [ -n "$e0" ] && [ $(( $(mape_epoch_utc 2026-07-19T15:37Z) - e0 )) -eq 3600 ]; } 2>/dev/null && ok "epoch: +1h=3600s" || ng "epoch: 時差が不正"
{ [ -n "$e0" ] && [ $(( $(mape_epoch_utc 2026-07-20T14:37Z) - e0 )) -eq 86400 ]; } 2>/dev/null && ok "epoch: +1d=86400s" || ng "epoch: 日差が不正"
{ [ $(( $(mape_epoch_utc 2026-08-01T00:00Z) - $(mape_epoch_utc 2026-07-31T23:00Z) )) -eq 3600 ]; } 2>/dev/null && ok "epoch: 月境界" || ng "epoch: 月境界が不正"
[ -z "$(mape_epoch_utc 'not-a-ts')" ] && ok "epoch: 不正形式は空（フェイルセーフ）" || ng "epoch: 不正形式で非空"
[ -z "$(mape_epoch_utc 2026-13-40T25:99Z)" ] && ok "epoch: 範囲外は空" || ng "epoch: 範囲外を受理"
if date -u -d 2026-07-19T14:37Z +%s >/dev/null 2>&1; then
  [ "$e0" = "$(date -u -d 2026-07-19T14:37Z +%s)" ] && ok "epoch: GNU date と一致" || ng "epoch: GNU date と不一致"
fi
# 23b. monitor が MAPE_STALE_H を算出
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_BACKLOG" "$tk/" 2>/dev/null
hdr='| ts(UTC) | cycle | gate | gate_s | todo | scripts | max_skill | claude_md | adr | note |'
printf '# H\n%s\n|---|---|---|---|---|---|---|---|---|---|\n| 2026-07-19T14:37Z | 1 | pass | 4 | 0 | 20 | 95 | 85 | 10 | monitor |\n' "$hdr" > "$tk/HEALTH.md"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
sh_old=$(grep '^MAPE_STALE_H=' "$MAPE_STATE_DIR/monitor.env" | cut -d= -f2)
{ [ "$sh_old" != '-' ] && [ "$sh_old" -ge 36 ] 2>/dev/null; } && ok "monitor: 古い ts→大きな stale_h（$sh_old）" || ng "monitor: 古い ts の stale_h が不正（$sh_old）"
now_ts=$(mape_now)
printf '# H\n%s\n|---|---|---|---|---|---|---|---|---|---|\n| %s | 1 | pass | 4 | 0 | 20 | 95 | 85 | 10 | monitor |\n' "$hdr" "$now_ts" > "$tk/HEALTH.md"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
sh_new=$(grep '^MAPE_STALE_H=' "$MAPE_STATE_DIR/monitor.env" | cut -d= -f2)
{ [ "$sh_new" != '-' ] && [ "$sh_new" -lt 36 ] 2>/dev/null; } && ok "monitor: 直近 ts→小さな stale_h（$sh_new）" || ng "monitor: 直近 ts の stale_h が不正（$sh_new）"
printf '# H\n%s\n|---|---|---|---|---|---|---|---|---|---|\n' "$hdr" > "$tk/HEALTH.md"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/monitor.sh" >/dev/null 2>&1
[ "$(grep '^MAPE_STALE_H=' "$MAPE_STATE_DIR/monitor.env" | cut -d= -f2)" = '-' ] && ok "monitor: 0 データ行は '-'（graceful）" || ng "monitor: 空 HEALTH で '-' にならない"
# 23c. analyze が休眠提案を出す/出さない（signal 由来＝BACKLOG 非永続）
printf '# B\n## 候補\n## アーカイブ\n' > "$tk/BACKLOG.md"; : > "$MAPE_STATE_DIR/ledger.jsonl"
base='MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\n'
printf "$base"'MAPE_STALE_H=100\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
grep -qF '休眠' "$tsv" && ok "analyze: 閾値超で休眠提案が出る" || ng "analyze: 休眠提案が出ない"
[ "$(awk -F'\t' '/休眠/{print $1"/"$2; exit}' "$tsv")" = auto/P1 ] && ok "analyze: 休眠は auto/P1（tier 不変）" || ng "analyze: 休眠の tier/prio が不正"
printf "$base"'MAPE_STALE_H=5\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
grep -qF '休眠' "$tsv" && ng "analyze: 閾値未満で誤発火" || ok "analyze: 直近なら休眠提案なし"
printf "$base"'MAPE_STALE_H=-\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
grep -qF '休眠' "$tsv" && ng "analyze: '-' で誤発火" || ok "analyze: 非数値は判定せず（graceful）"
printf "$base"'MAPE_STALE_H=100\n' > "$MAPE_STATE_DIR/monitor.env"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" --update-knowledge >/dev/null 2>&1
grep -qF '休眠' "$tk/BACKLOG.md" && ng "analyze: 休眠(signal)が BACKLOG に焼き付く（ゾンビ）" || ok "analyze: 休眠は BACKLOG 非永続"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "24. 項目隔離（quarantine）: 毒項目1件で全停止しない（自己修復。ADR-0015） — NFR-REL-001"
cb="$MAPE_DIR/circuit-breaker.sh"
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$tk/" 2>/dev/null
# 隔離する item は analyze が抽出する「本文」と一致させる（Execute が record/quarantine する文字列＝提案テキスト）
printf '# B\n## 候補\n- [ ] (P2, approve) 毒項目テキスト — t\n- [ ] (P2, approve) 健全項目テキスト — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
qitem='毒項目テキスト — t'
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" quarantine "$qitem" "2度赤" >/dev/null 2>&1
grep -qxF '## ブロック中' "$tk/BACKLOG.md" && ok "quarantine: ## ブロック中 を生成" || ng "quarantine: セクション未生成/未実装"
qn() { ( MAPE_BACKLOG="$tk/BACKLOG.md"; mape_quarantined_items | grep -c . ); }
[ "$(qn)" = 1 ] && ok "quarantine: 1 エントリ追記" || ng "quarantine: 追記数が不正（$(qn)）"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" quarantine "$qitem" "2度赤" >/dev/null 2>&1
[ "$(qn)" = 1 ] && ok "quarantine: 冪等（二重追記しない）" || ng "quarantine: 冪等でない（$(qn)）"
( MAPE_BACKLOG="$tk/BACKLOG.md"; mape_is_quarantined "$qitem" ) && ok "is_quarantined: 隔離済みを検出" || ng "is_quarantined: 検出漏れ"
( MAPE_BACKLOG="$tk/BACKLOG.md"; mape_is_quarantined "健全項目テキスト — t" ) && ng "is_quarantined: 無関係を誤検出" || ok "is_quarantined: 無関係は false"
# [8] 部分一致による過剰抑止の回帰: 隔離エントリの部分文字列（項目の途中・reason 語）は隔離扱いにしない
( MAPE_BACKLOG="$tk/BACKLOG.md"; mape_is_quarantined "項目テキスト" ) && ng "is_quarantined: 部分文字列を誤検出（過剰抑止）" || ok "is_quarantined: 項目の部分文字列は隔離扱いにしない"
( MAPE_BACKLOG="$tk/BACKLOG.md"; mape_is_quarantined "2度赤" ) && ng "is_quarantined: reason 語を誤検出" || ok "is_quarantined: reason 語は隔離扱いにしない"
# 隔離項目の部分文字列である別項目は、同一項目トリップを黙らされない（安全境界・GLOBAL 保護）
: > "$MAPE_STATE_DIR/ledger.jsonl"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "項目テキスト" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "項目テキスト" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "backstop: 隔離項目の部分文字列でも同一項目トリップは黙らされない" || ng "backstop: 部分一致で同一項目トリップが過剰抑止"
rm -f "$MAPE_STATE_DIR/ledger.jsonl"
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\nMAPE_STALE_H=-\n' > "$MAPE_STATE_DIR/monitor.env"
: > "$MAPE_STATE_DIR/ledger.jsonl"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
grep -qF '毒項目テキスト' "$tsv" && ng "analyze: 隔離済みを再提案してしまう" || ok "analyze: 隔離済みは再提案しない"
grep -qF '健全項目テキスト' "$tsv" && ok "analyze: 健全項目は通常提案" || ng "analyze: 健全項目が消えた"
rm -f "$MAPE_STATE_DIR/ledger.jsonl"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "別A" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "別B" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "別C" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "backstop: 末尾連続 red 3 で停止（隔離と独立）" || ng "backstop: 連続 red が停止しない"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "25. 有界なブレーカー自己修復（隔離クリア）— NFR-REL-001（ADR-0015）"
cb="$MAPE_DIR/circuit-breaker.sh"
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$tk/" 2>/dev/null
printf '# B\n## 候補\n- [ ] (P2, approve) 毒項目テキスト — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
rm -f "$MAPE_STATE_DIR/ledger.jsonl" "$MAPE_STATE_DIR/breaker.tripped_at"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "毒項目テキスト" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "毒項目テキスト" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "隔離前: 同一項目 red×2 は tripped" || ng "隔離前: 停止しない"
[ -f "$MAPE_STATE_DIR/breaker.tripped_at" ] && ok "tripped_at を記録" || ng "tripped_at 未記録"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" quarantine "毒項目テキスト" "同一赤上限" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 0 ] && ok "隔離後: 同一項目トリップは自動クリア(ok)" || ng "隔離後: ok に戻らない"
[ -f "$MAPE_STATE_DIR/breaker.tripped_at" ] && ng "ok 復帰後も tripped_at が残る" || ok "ok 復帰で tripped_at を消去"
rm -f "$MAPE_STATE_DIR/ledger.jsonl" "$MAPE_STATE_DIR/breaker.tripped_at"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "R1" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "R2" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "R3" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" quarantine "R3" "隔離しても暴走は止める" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "backstop: 末尾連続 red は隔離でも解除されない" || ng "backstop: 連続 red が隔離で誤クリア（安全境界侵食）"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" reset >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record green "回復確認" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 0 ] && ok "reset 後は ok（手動 reset 不変）" || ng "reset が効かない"
# [10] GLOBAL window-red 暴走停止を単独で検査する: 末尾連続 red でも同一項目でもなく、直近 window に
# 別項目 red が REVERT_MAX 件 → trip。かつ隔離しても解除されない（item 非依存の最終防壁）。
rm -f "$MAPE_STATE_DIR/ledger.jsonl" "$MAPE_STATE_DIR/breaker.tripped_at"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red   "W1" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red   "W2" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record green "W3" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red   "W4" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record green "W5" >/dev/null 2>&1   # 末尾は green（trailing=0）
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "backstop: window-red 単独（末尾/同一項目でない）で停止（[10]）" || ng "window-red 単独で停止しない"
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" quarantine "W1" "隔離しても window は止める" >/dev/null 2>&1
MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "backstop: window-red は隔離でも解除されない（GLOBAL 最終防壁）" || ng "window-red が隔離で誤クリア（安全境界侵食）"
# [3] cooldown-dwell（MAPE_CB_COOLDOWN_H>0）: 隔離しても最小 dwell 未経過なら同一項目トリップを保持し、
# 経過後にクリアする（回復を遅らせるだけで暴走停止は緩めない。ADR-0015。従来テストは COOLDOWN 未設定で穴）。
if date -u -d '25 hours ago' +%Y-%m-%dT%H:%MZ >/dev/null 2>&1 || date -u -v-25H +%Y-%m-%dT%H:%MZ >/dev/null 2>&1; then
  rm -f "$MAPE_STATE_DIR/ledger.jsonl" "$MAPE_STATE_DIR/breaker.tripped_at"
  MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "Q項目" >/dev/null 2>&1
  MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" record red "Q項目" >/dev/null 2>&1
  MAPE_CB_COOLDOWN_H=24 MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "cooldown: 同一項目 red2 で tripped（tripped_at 記録）" || ng "cooldown: 初回 tripped せず"
  MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" quarantine "Q項目" "毒" >/dev/null 2>&1
  MAPE_CB_COOLDOWN_H=24 MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "cooldown: dwell 未経過は隔離クリアを遅らせ tripped 維持（[3]）" || ng "cooldown: dwell 未経過で早期クリア"
  old=$(date -u -d '25 hours ago' +%Y-%m-%dT%H:%MZ 2>/dev/null || date -u -v-25H +%Y-%m-%dT%H:%MZ 2>/dev/null)
  printf '%s\n' "$old" > "$MAPE_STATE_DIR/breaker.tripped_at"
  MAPE_CB_COOLDOWN_H=24 MAPE_KNOWLEDGE_DIR="$tk" bash "$cb" status >/dev/null 2>&1; [ $? -eq 0 ] && ok "cooldown: dwell 経過後は隔離クリア→ok（有界回復）" || ng "cooldown: dwell 経過してもクリアしない"
fi
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl" "$MAPE_STATE_DIR/breaker.tripped_at"

# ---------------------------------------------------------------------------
sec "26. 安全状態（safe-state）: 危険時は Execute を抑止する — NFR-SAFE-001 / NFR-SAFE-002"
# Verifies: NFR-SAFE-001  Verifies: NFR-SAFE-002
ss="$MAPE_DIR/safe-state.sh"
: > "$MAPE_STATE_DIR/ledger.jsonl"   # ブレーカー ok を保証（空台帳）
if ! command -v git >/dev/null 2>&1; then
  MAPE_GIT_ROOT="$TMP" bash "$ss" >/dev/null 2>&1
  [ $? -eq 1 ] && ok "git 不在: フェイルセーフで unsafe(exit1)" || ng "git 不在で unsafe にならない/未実装"
else
  KG="$TMP/kg-good"; rm -rf "$KG"; mkdir -p "$KG"
  cp "$MAPE_HEALTH" "$MAPE_POLICY" "$MAPE_BACKLOG" "$MAPE_PROGRESS" "$KG/" 2>/dev/null
  KB="$TMP/kg-bad"; rm -rf "$KB"; cp -r "$KG" "$KB"; printf '# broken HEALTH（推移表ヘッダ無し）\n' > "$KB/HEALTH.md"
  mkrepo() { GR="$TMP/repo.$1"; rm -rf "$GR"; mkdir -p "$GR"; git -C "$GR" init -q
    git -C "$GR" config user.email t@t; git -C "$GR" config user.name t
    ( cd "$GR" && echo x > f.txt && git -C "$GR" add f.txt && git -C "$GR" commit -qm init ); }
  tomain() { local c; c=$(git -C "$GR" branch --show-current); [ "$c" = main ] || git -C "$GR" branch -m main 2>/dev/null; }
  run_ss() { MAPE_GIT_ROOT="$1" MAPE_KNOWLEDGE_DIR="$2" MAPE_STATE_DIR="$MAPE_STATE_DIR" bash "$ss" 2>/dev/null | grep -E '^MAPE_SAFE=' | tail -1 | cut -d= -f2-; }
  mkrepo topic; git -C "$GR" checkout -qb feature/x
  [ "$(run_ss "$GR" "$KG")" = 1 ] && ok "健全(topic+clean+green) → MAPE_SAFE=1" || ng "健全なのに unsafe"
  mkrepo onmain; tomain
  [ "$(run_ss "$GR" "$KG")" = 0 ] && ok "保護ブランチ(main) → MAPE_SAFE=0" || ng "main 上で unsafe にならない"
  mkrepo topic2; git -C "$GR" checkout -qb feature/y
  [ "$(run_ss "$GR" "$KB")" = 0 ] && ok "knowledge 破損 → MAPE_SAFE=0" || ng "破損 knowledge で unsafe にならない"
  mkrepo dirty; git -C "$GR" checkout -qb feature/z; ( cd "$GR" && echo mod >> f.txt )
  [ "$(run_ss "$GR" "$KG")" = 0 ] && ok "dirty tree → MAPE_SAFE=0" || ng "dirty tree で unsafe にならない"
  # [9] MAPE 自身の証跡 mape/state/ の churn は clean 判定を汚さない（自己 churn で Execute を止めない）
  mkrepo selfchurn; git -C "$GR" checkout -qb feature/sc
  mkdir -p "$GR/mape/state"; echo committed > "$GR/mape/state/monitor.env"
  git -C "$GR" add mape/state/monitor.env >/dev/null 2>&1; git -C "$GR" commit -qm addstate >/dev/null 2>&1
  ( cd "$GR" && echo churn >> mape/state/monitor.env && echo scratch > mape/state/new.tmp )
  [ "$(run_ss "$GR" "$KG")" = 1 ] && ok "mape/state の自己 churn は clean を汚さない（[9]・false-positive 回避）" || ng "mape/state の自己 churn で誤って unsafe"
  ( cd "$GR" && echo realcode >> f.txt )   # 対照: コードの未コミット変更は依然 unsafe
  [ "$(run_ss "$GR" "$KG")" = 0 ] && ok "mape/state 以外の未コミット変更は unsafe 維持（安全境界不変）" || ng "コード dirty を見逃す（安全境界侵食）"
  # [11] 不変条件4（ブレーカー非tripped）の結合を検査する: 健全な topic+clean+green でも、ブレーカーが
  # tripped なら MAPE_SAFE=0（それ以外の全条件を満たすことで breaker 単独の寄与を分離する）
  mkrepo brk; git -C "$GR" checkout -qb feature/brk
  # ts を含める（欠落すると invariant 2=knowledge 整合性が独立に unsafe を強制し、ブレーカー結合を
  # 検査したことにならない＝false-green。ts 付きで DNA を健全に保ち breaker 単独の寄与を分離する）。
  printf '%s\n' '{"ts":"t","item":"A","result":"red"}' '{"ts":"t","item":"B","result":"red"}' '{"ts":"t","item":"C","result":"red"}' > "$MAPE_STATE_DIR/ledger.jsonl"
  [ "$(run_ss "$GR" "$KG")" = 0 ] && ok "ブレーカー tripped → MAPE_SAFE=0（不変条件4の結合・[11]）" || ng "tripped breaker で safe-state が unsafe にならない"
  : > "$MAPE_STATE_DIR/ledger.jsonl"   # 後続の健全前提へ台帳を空へ戻す
  # [10] detached HEAD（ブランチ不明）は保護ブランチ判定が効かないためフェイルセーフで unsafe に倒す
  mkrepo dethead; git -C "$GR" checkout -q --detach 2>/dev/null
  [ "$(run_ss "$GR" "$KG")" = 0 ] && ok "detached HEAD → MAPE_SAFE=0（ブランチ不明のフェイルセーフ・[10]）" || ng "detached HEAD で unsafe にならない"
  ND="$TMP/nogit"; rm -rf "$ND"; mkdir -p "$ND"
  [ "$(run_ss "$ND" "$KG")" = 0 ] && ok "非 git ディレクトリ → フェイルセーフ MAPE_SAFE=0" || ng "非 git で unsafe にならない"
  MAPE_GIT_ROOT="$ND" MAPE_KNOWLEDGE_DIR="$KG" MAPE_STATE_DIR="$MAPE_STATE_DIR" bash "$ss" >/dev/null 2>&1
  [ $? -eq 1 ] && ok "unsafe 時 exit1（Execute はこれで抑止判定）— NFR-SAFE-002" || ng "unsafe で exit1 にならない"
  mkrepo forrun; tomain
  MAPE_GIT_ROOT="$GR" MAPE_KNOWLEDGE_DIR="$KG" MAPE_STATE_DIR="$MAPE_STATE_DIR" bash "$MAPE_DIR/run.sh" >/dev/null 2>&1
  grep -qF 'safe-state=0' "$MAPE_STATE_DIR/issue-body.md" 2>/dev/null \
    && ok "run.sh: unsafe 時 issue-body に Execute 抑止バナー" || ng "run.sh が Execute 抑止を掲示しない"
fi
rm -f "$MAPE_STATE_DIR/ledger.jsonl" "$MAPE_STATE_DIR/safe.env"

# ---------------------------------------------------------------------------
sec "27. 自己設定: POLICY 重点テーマで同スコア提案を上位へ（ADR-0014） — REQ-MAPE-002"
pol27="$TMP/pol27.md"; printf '## 今月の重点テーマ\n\n- セキュリティ\n\n## 次\n' > "$pol27"
[ "$(MAPE_POLICY="$pol27" mape_theme_of 'セキュリティ強化のテスト')" = 'セキュリティ' ] && ok "theme_of: 一致を返す" || ng "theme_of: 一致を返さない/未実装"
[ -z "$(MAPE_POLICY="$pol27" mape_theme_of '無関係な整形')" ] && ok "theme_of: 非該当は空" || ng "theme_of: 非該当で誤検出"
[ "$(MAPE_POLICY="$pol27" mape_theme_boost 'セキュリティ強化')" -gt 0 ] 2>/dev/null && ok "theme_boost: 一致は加点>0" || ng "theme_boost: 加点なし"
[ "$(MAPE_POLICY="$pol27" mape_theme_boost '無関係')" -eq 0 ] 2>/dev/null && ok "theme_boost: 非該当は0" || ng "theme_boost: 非該当で加点"
tk=$(mktemp -d); cp "$MAPE_HEALTH" "$tk/"; cp "$pol27" "$tk/POLICY.md"
printf '# B\n## 候補\n- [ ] (P2, approve) セキュリティ の穴を塞ぐ — t\n- [ ] (P2, approve) 無害な整理をする — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\nMAPE_STALE_H=-\n' > "$MAPE_STATE_DIR/monitor.env"
: > "$MAPE_STATE_DIR/ledger.jsonl"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
ss27=$(grep -nF 'セキュリティ の穴' "$tsv" | cut -d: -f1); ns27=$(grep -nF '無害な整理' "$tsv" | cut -d: -f1)
{ [ -n "$ss27" ] && [ -n "$ns27" ] && [ "$ss27" -lt "$ns27" ]; } 2>/dev/null && ok "theme: 一致提案が上位（行 $ss27<$ns27）" || ng "theme: 上位化しない（sec=$ss27 non=$ns27）"
[ "$(grep -F 'セキュリティ の穴' "$tsv" | cut -f1)" = approve ] && ok "theme: tier 不変(approve・安全境界)" || ng "theme: tier が変わった"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "28. トレンド微分感知: 上昇3周で先回り・希薄は no-op（ADR-0014） — REQ-MAPE-002"
mkhealth() { printf '| ts(UTC) | cycle | gate | gate_s | todo | scripts | max_skill | claude_md | adr | note |\n|---|---|---|---|---|---|---|---|---|---|\n' > "$1"; }
h28="$TMP/health28.md"; mkhealth "$h28"
printf '| 2026-01-01T00:00Z | 1 | pass | 4 | 2 | 20 | 95 | 85 | 10 | monitor |\n' >> "$h28"
printf '| 2026-01-02T00:00Z | 2 | pass | 4 | 3 | 20 | 95 | 85 | 10 | monitor |\n' >> "$h28"
[ "$(MAPE_HEALTH="$h28" mape_trend todo)" = unknown ] && ok "trend: <3行は unknown（graceful）" || ng "trend: 希薄で unknown を返さない/未実装"
printf '| 2026-01-03T00:00Z | 3 | pass | 4 | 5 | 20 | 95 | 85 | 10 | monitor |\n' >> "$h28"
tr=$(MAPE_HEALTH="$h28" mape_trend todo); set -- $tr
{ [ "$1" = rising ] && [ "${2:-0}" -ge 3 ]; } 2>/dev/null && ok "trend: 2/3/5 は rising streak>=3（$tr）" || ng "trend: 上昇を検知しない（$tr）"
case "$(MAPE_HEALTH="$h28" mape_trend claude_md)" in flat*) ok "trend: 一定値は flat";; *) ng "trend: 一定値を flat にしない";; esac
# 統合: 予算指標 claude_md（既定 band 190/200＝ok に余白）を実運用の既定しきい値で回す。
# ここが要: 配線先は「band=ok に余白のある予算指標」であり todo のような ok幅≒0 の指標では
# 永久に発火しない（レビュー所見#1 の死にパスを回帰で固定）。POLICY で band を差し替えない。
tk=$(mktemp -d)
mkhealth "$tk/HEALTH.md"
printf '# B\n## 候補\n## アーカイブ\n' > "$tk/BACKLOG.md"
: > "$MAPE_STATE_DIR/ledger.jsonl"
cmenv() { printf 'MAPE_GATE=pass\nMAPE_CYCLE=3\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=%s\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\nMAPE_STALE_H=-\n' "$1" > "$MAPE_STATE_DIR/monitor.env"; }
# 希薄(<3行): 誤発火しない
printf '| 2026-01-01T00:00Z | 1 | pass | 4 | 0 | 20 | 95 | 180 | 10 | monitor |\n' >> "$tk/HEALTH.md"
printf '| 2026-01-02T00:00Z | 2 | pass | 4 | 0 | 20 | 95 | 185 | 10 | monitor |\n' >> "$tk/HEALTH.md"
cmenv 185
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
grep -qF '上昇トレンド継続中' "$MAPE_STATE_DIR/proposals.tsv" && ng "trend: 2行(希薄)で早期警告が誤発火" || ok "trend: 希薄(<3行)は no-op"
# 3行・band=ok（claude_md 180→185→188 < warn190）: 早期警告を追加
printf '| 2026-01-03T00:00Z | 3 | pass | 4 | 0 | 20 | 95 | 188 | 10 | monitor |\n' >> "$tk/HEALTH.md"
cmenv 188
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv="$MAPE_STATE_DIR/proposals.tsv"
grep -qF 'CLAUDE.md 行数が上昇トレンド継続中' "$tsv" && ok "trend: band内の上昇3周で早期警告を追加（既定しきい値）" || ng "trend: 既定しきい値で上昇を提案化しない（死にパス）"
[ "$(grep -F '上昇トレンド継続中' "$tsv" | cut -f1)" = auto ] && ok "trend: tier は auto 不変（安全境界）" || ng "trend: tier が変わった"
# band を出た指標（claude_md 191→195→198 >= warn190）: trend は静かに（emit_band が担当・二重掲示しない）
mkhealth "$tk/HEALTH.md"
printf '| 2026-01-01T00:00Z | 1 | pass | 4 | 0 | 20 | 95 | 191 | 10 | monitor |\n' >> "$tk/HEALTH.md"
printf '| 2026-01-02T00:00Z | 2 | pass | 4 | 0 | 20 | 95 | 195 | 10 | monitor |\n' >> "$tk/HEALTH.md"
printf '| 2026-01-03T00:00Z | 3 | pass | 4 | 0 | 20 | 95 | 198 | 10 | monitor |\n' >> "$tk/HEALTH.md"
cmenv 198
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
grep -qF '上昇トレンド継続中' "$MAPE_STATE_DIR/proposals.tsv" && ng "trend: band逸脱中に trend が二重発火" || ok "trend: band逸脱中は trend 静か（emit_band が担当）"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "29. 効き目感知: 台帳から係数を学習し採点へ還元（ADR-0014） — REQ-MAPE-002 / NFR-OPT-001"
# Verifies: REQ-MAPE-002
# Verifies: NFR-OPT-001
eff="$MAPE_DIR/efficacy.sh"
pol29="$TMP/pol29.md"; printf '## 今月の重点テーマ\n\n- セキュリティ\n- パフォーマンス\n\n## 次\n' > "$pol29"
led="$MAPE_STATE_DIR/ledger.jsonl"; efftsv="$MAPE_STATE_DIR/efficacy.tsv"
# セキュリティ: green×3 red×0 → improved / パフォーマンス: green×1 red×2 → worsened
{
  printf '{"ts":"t","item":"セキュリティ の穴A","result":"green","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"セキュリティ の穴B","result":"green","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"セキュリティ の穴C","result":"green","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"パフォーマンス 改善X","result":"green","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"パフォーマンス 改善Y","result":"red","pr":"","branch":""}\n'
  printf '{"ts":"t","item":"パフォーマンス 改善Z","result":"red","pr":"","branch":""}\n'
} > "$led"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_POLICY="$pol29" bash "$eff" >/dev/null 2>&1
[ -f "$efftsv" ] && ok "efficacy: tsv を生成" || ng "efficacy: tsv 未生成/未実装"
[ "$(awk -F'\t' '$1=="セキュリティ"{print $5}' "$efftsv" 2>/dev/null)" = improved ] && ok "efficacy: 全green は improved" || ng "efficacy: improved 判定せず"
[ "$(awk -F'\t' '$1=="パフォーマンス"{print $5}' "$efftsv" 2>/dev/null)" = worsened ] && ok "efficacy: red優勢は worsened" || ng "efficacy: worsened 判定せず"
[ "$(MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_POLICY="$pol29" mape_effectiveness_factor セキュリティ)" = 12 ] && ok "factor: improved は 12（加点）" || ng "factor: improved を加点せず"
[ "$(MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_POLICY="$pol29" mape_effectiveness_factor パフォーマンス)" = 7 ] && ok "factor: worsened は 7（減点）" || ng "factor: worsened を減点せず"
# graceful: 台帳が壊れた行を含んでも生成を継続する（パーサ耐性）
printf 'THIS IS NOT JSON\n' >> "$led"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_POLICY="$pol29" bash "$eff" >/dev/null 2>&1
[ "$(awk -F'\t' '$1=="セキュリティ"{print $5}' "$efftsv" 2>/dev/null)" = improved ] && ok "efficacy: 破損行を無視して集計継続" || ng "efficacy: 破損行で崩れる"
# jq フォールバック経路（python3 を隠す。while の EOF 非0戻りで fail-safe が誤発火しないことを固定）
if command -v jq >/dev/null 2>&1; then
  sb=$(mktemp -d); oifs=$IFS; IFS=:
  for d in $PATH; do [ -d "$d" ] || continue; for f in "$d"/*; do [ -x "$f" ] || continue; bn=$(basename "$f"); [ "$bn" = python3 ] && continue; [ -e "$sb/$bn" ] || ln -s "$f" "$sb/$bn" 2>/dev/null; done; done
  IFS=$oifs
  rm -f "$efftsv"
  MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_POLICY="$pol29" PATH="$sb" bash "$eff" >/dev/null 2>&1
  [ "$(awk -F'\t' '$1=="セキュリティ"{print $5}' "$efftsv" 2>/dev/null)" = improved ] && ok "efficacy: jq フォールバックでも集計する（fail-safe 誤発火なし）" || ng "efficacy: jq 経路で空になる"
  rm -rf "$sb"
fi
# 統合: 効き目は採点に効くが tier は不変（安全境界・NFR-OPT-001）
tk=$(mktemp -d); cp "$MAPE_HEALTH" "$tk/"; cp "$pol29" "$tk/POLICY.md"
printf '# B\n## 候補\n- [ ] (P2, approve) セキュリティ の穴を塞ぐ — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\nMAPE_STALE_H=-\n' > "$MAPE_STATE_DIR/monitor.env"
printf 'セキュリティ\t3\t3\t0\timproved\n' > "$efftsv"
: > "$led"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
[ "$(grep -F 'セキュリティ の穴' "$MAPE_STATE_DIR/proposals.tsv" | cut -f1)" = approve ] && ok "efficacy: tier 不変(approve・安全境界)" || ng "efficacy: tier が変わった"
# [27] 効き目が score に実際に効くことを検査する（factor を score 合成から外すと落ちる）。
# 同 tier・同 base の2候補で improved テーマ(factor12)の score が worsened テーマ(factor7)を上回る。
# score を直接比較する（同点時の sort tie-break に依存しない確実な判別）。
tk2=$(mktemp -d); cp "$MAPE_HEALTH" "$tk2/"; cp "$pol29" "$tk2/POLICY.md"
printf '# B\n## 候補\n- [ ] (P2, approve) パフォーマンス を改善 — t\n- [ ] (P2, approve) セキュリティ を強化 — t\n## アーカイブ\n' > "$tk2/BACKLOG.md"
printf 'セキュリティ\t3\t3\t0\timproved\nパフォーマンス\t3\t1\t2\tworsened\n' > "$efftsv"
: > "$led"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk2" bash "$MAPE_DIR/analyze.sh" >/dev/null 2>&1
tsv2="$MAPE_STATE_DIR/proposals.tsv"
ssec=$(grep -F 'セキュリティ を強化' "$tsv2" | cut -f5); sperf=$(grep -F 'パフォーマンス を改善' "$tsv2" | cut -f5)
{ [ -n "$ssec" ] && [ -n "$sperf" ] && [ "$ssec" -gt "$sperf" ]; } 2>/dev/null && ok "efficacy: improved の score が worsened を上回る（factor が採点に効く・[27]）" || ng "efficacy: 効き目が score に反映されない（sec=$ssec perf=$sperf）"
rm -rf "$tk" "$tk2"; rm -f "$led" "$efftsv"

# ---------------------------------------------------------------------------
sec "30. パーサ堅牢性: 非オブジェクト行・不正UTF-8・パーサ欠落でも安全側（NFR-REL-001 / 敵対的）"
# Verifies: NFR-REL-001
cb="$MAPE_DIR/circuit-breaker.sh"
# 全 PATH 実行体を symlink し、指定ツールだけ隠す sandbox（ツール欠落の敵対テスト）
mkbin() { local bin="$1"; shift; local hide=" $* " d f n oi; rm -rf "$bin"; mkdir -p "$bin"; oi=$IFS; IFS=:
  for d in $PATH; do [ -d "$d" ] || continue; for f in "$d"/*; do [ -x "$f" ] || continue; n=$(basename "$f"); case "$hide" in *" $n "*) continue;; esac; [ -e "$bin/$n" ] || ln -s "$f" "$bin/$n" 2>/dev/null; done; done; IFS=$oi; }
st30="$TMP/st30"
runaway() { printf '%s\n' '{"ts":"t","item":"A","result":"red"}' '{"ts":"t","item":"B","result":"red"}' '{"ts":"t","item":"C","result":"red"}' > "$1"; }
# 末尾連続 red 3件（GLOBAL 暴走）は毒行が混ざっても必ず tripped(rc=3) を維持する（fail-open 厳禁）
for badcase in 'scalar:123' 'array:[1,2]' 'objitem:{"item":{"x":1},"result":"red"}'; do
  lbl=${badcase%%:*}; bad=${badcase#*:}
  rm -rf "$st30"; mkdir -p "$st30"; runaway "$st30/ledger.jsonl"; printf '%s\n' "$bad" >> "$st30/ledger.jsonl"
  MAPE_STATE_DIR="$st30" bash "$cb" status >/dev/null 2>&1
  [ $? -eq 3 ] && ok "cb: 毒行($lbl)混在でも末尾連続redはtripped維持（python3経路）" || ng "cb: 毒行($lbl)で暴走停止がfail-open"
done
rm -rf "$st30"; mkdir -p "$st30"; runaway "$st30/ledger.jsonl"; printf '\xff\xfe bad\n' >> "$st30/ledger.jsonl"
MAPE_STATE_DIR="$st30" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "cb: 不正UTF-8行でもtripped維持（python3経路）" || ng "cb: 不正UTF-8でfail-open"
if command -v jq >/dev/null 2>&1; then
  sb30="$TMP/sb30"; mkbin "$sb30" python3
  rm -rf "$st30"; mkdir -p "$st30"; runaway "$st30/ledger.jsonl"; printf '%s\n' '123' >> "$st30/ledger.jsonl"
  MAPE_STATE_DIR="$st30" PATH="$sb30" bash "$cb" status >/dev/null 2>&1; [ $? -eq 3 ] && ok "cb: 毒行混在でもtripped維持（jq経路）" || ng "cb: jq経路で暴走停止がfail-open"
  rm -rf "$sb30"
fi
# done: green 項目 + 毒行 → 実装済み(exit0) を維持（毒行で未実装扱い＝二重実行を防ぐ）。jq/python3 両経路。
# 毒行を green の **前** に置く（green-first だとループが緑で先に exit し毒行を読まず、
# done の per-line 耐性を検査できない＝false-green。[1] 是正）。
rm -rf "$st30"; mkdir -p "$st30"; printf '%s\n' '123' '{"ts":"t","item":"実装済みX","result":"green"}' > "$st30/ledger.jsonl"
MAPE_STATE_DIR="$st30" bash "$cb" done "実装済みX" >/dev/null 2>&1; [ $? -eq 0 ] && ok "cb done: 毒行(先頭)を越えて green 項目を実装済み判定（jq経路）" || ng "cb done: 毒行で実装済みを見落とす（jq）"
if command -v python3 >/dev/null 2>&1; then
  sbjq="$TMP/sbjq"; mkbin "$sbjq" jq
  MAPE_STATE_DIR="$st30" PATH="$sbjq" bash "$cb" done "実装済みX" >/dev/null 2>&1; [ $? -eq 0 ] && ok "cb done: 毒行(先頭)を越えて実装済み判定（python3経路）" || ng "cb done: python3経路が毒行で落ちる"
fi
# mape_ledger_status: 毒行(先頭) + green → done を維持。毒行を green の前に置き、毒行で while が
# 中断すると後続 green を数え落として done を落とす回帰を確実に検出する。jq/python3 両経路。
rm -rf "$st30"; mkdir -p "$st30"; printf '%s\n' '123' '{"ts":"t","item":"項目Y","result":"green"}' > "$st30/ledger.jsonl"
[ "$(MAPE_STATE_DIR="$st30" mape_ledger_status "項目Y")" = done ] && ok "mape_ledger_status: 毒行混在でも done（jq経路）" || ng "mape_ledger_status: 毒行で done を落とす（jq）"
if command -v python3 >/dev/null 2>&1; then
  r=$(PATH="$TMP/sbjq" MAPE_STATE_DIR="$st30" bash -c '. "'"$MAPE_DIR"'/lib.sh"; mape_ledger_status "項目Y"')
  [ "$r" = done ] && ok "mape_ledger_status: 毒行混在でも done（python3経路）" || ng "mape_ledger_status: python3経路が毒行で落ちる"
fi
# efficacy: 毒行を挟んでも後続の有効行を落とさない（per-line 耐性・python3経路）
pol30="$TMP/pol30.md"; printf '## 今月の重点テーマ\n\n- セキュリティ\n\n## 次\n' > "$pol30"
rm -rf "$st30"; mkdir -p "$st30"
printf '%s\n' '{"ts":"t","item":"セキュリティ A","result":"green"}' '{"ts":"t","item":"セキュリティ B","result":"green"}' '123' '{"ts":"t","item":"セキュリティ C","result":"green"}' > "$st30/ledger.jsonl"
MAPE_STATE_DIR="$st30" MAPE_POLICY="$pol30" bash "$MAPE_DIR/efficacy.sh" >/dev/null 2>&1
[ "$(awk -F'\t' '$1=="セキュリティ"{print $2}' "$st30/efficacy.tsv" 2>/dev/null)" = 3 ] && ok "efficacy: 毒行後の有効行も数える（samples=3）" || ng "efficacy: 毒行後の行を落とす（per-line非耐性）"
# record: パーサ皆無でも記録を落とさない（フェイルセーフで追記＝ブレーカーを盲目にしない）
sbnone="$TMP/sbnone"; mkbin "$sbnone" python3 jq
rm -rf "$st30"; mkdir -p "$st30"
MAPE_STATE_DIR="$st30" PATH="$sbnone" bash "$cb" record red "項目Z" >/dev/null 2>&1
[ -s "$st30/ledger.jsonl" ] && ok "cb record: パーサ皆無でも台帳へ追記（記録欠落せず）" || ng "cb record: パーサ皆無で記録を落とす"
# [2] status はパーサ皆無で fail-open してはならない: 暴走台帳を「ok(0)」で通すと safe-state が
# 無人 Execute を許可してしまう。安全側（非0＝状態不明→safe-state unsafe）へ倒す。
rm -rf "$st30"; mkdir -p "$st30"; runaway "$st30/ledger.jsonl"
MAPE_STATE_DIR="$st30" PATH="$sbnone" bash "$cb" status >/dev/null 2>&1; rcnp=$?
[ "$rcnp" -ne 0 ] && ok "cb status: パーサ皆無で暴走台帳を fail-open しない（rc=$rcnp≠0・安全側）" || ng "cb status: パーサ皆無で fail-open（暴走を握り潰す）"
rm -rf "$st30" "$sbnone"
# [0] mape_verify_knowledge は不正UTF-8を含む台帳でも jq/python3 が同じ verdict を返す（決定論ゲート）
if command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  kdir="$TMP/kdna"; rm -rf "$kdir"; mkdir -p "$kdir"; cp "$MAPE_HEALTH" "$MAPE_POLICY" "$MAPE_BACKLOG" "$MAPE_PROGRESS" "$kdir/" 2>/dev/null
  stv="$TMP/stv"; rm -rf "$stv"; mkdir -p "$stv"
  printf '{"ts":"t","item":"x\xffy","result":"green","pr":"1"}\n' > "$stv/ledger.jsonl"   # 有効JSON・item に不正UTF-8
  sbA="$TMP/sbA"; mkbin "$sbA" python3   # jq only
  sbB="$TMP/sbB"; mkbin "$sbB" jq        # python3 only
  rjq=$(PATH="$sbA" bash -c '. "'"$MAPE_DIR"'/lib.sh"; MAPE_KNOWLEDGE_DIR="'"$kdir"'" MAPE_STATE_DIR="'"$stv"'" mape_verify_knowledge >/dev/null 2>&1; echo $?')
  rpy=$(PATH="$sbB" bash -c '. "'"$MAPE_DIR"'/lib.sh"; MAPE_KNOWLEDGE_DIR="'"$kdir"'" MAPE_STATE_DIR="'"$stv"'" mape_verify_knowledge >/dev/null 2>&1; echo $?')
  [ "$rjq" = "$rpy" ] && ok "verify_knowledge: 不正UTF-8で jq/python3 が同一 verdict（rc=$rjq・決定論ゲート）" || ng "verify_knowledge: バックエンドで verdict 相違（jq=$rjq py=$rpy・非決定論）"
  rm -rf "$kdir" "$stv" "$sbA" "$sbB"
fi
# [4] efficacy: item のタブを jq/python3 とも空白正規化し、テーマ帰属をバックエンド非依存にする
if command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  poltab="$TMP/poltab.md"; printf '## 今月の重点テーマ\n\n- セキュリティ 強化\n\n## 次\n' > "$poltab"
  sttab="$TMP/sttab"; rm -rf "$sttab"; mkdir -p "$sttab"
  # JSON エスケープ \t（有効な JSON）。パースすると item 値に実タブが入り、python は空白正規化、jq は
  # （未修正なら）タブ保持でテーマ帰属が食い違う。修正後は両経路で正規化され一致する。
  printf '{"ts":"t","item":"セキュリティ\\t強化 A","result":"green"}\n{"ts":"t","item":"セキュリティ\\t強化 B","result":"green"}\n{"ts":"t","item":"セキュリティ\\t強化 C","result":"green"}\n' > "$sttab/ledger.jsonl"
  sbTA="$TMP/sbTA"; mkbin "$sbTA" python3   # jq path
  sbTB="$TMP/sbTB"; mkbin "$sbTB" jq        # python3 path
  PATH="$sbTA" MAPE_STATE_DIR="$sttab" MAPE_POLICY="$poltab" bash "$MAPE_DIR/efficacy.sh" >/dev/null 2>&1; sjq=$(awk -F'\t' '$1=="セキュリティ 強化"{print $2}' "$sttab/efficacy.tsv" 2>/dev/null)
  PATH="$sbTB" MAPE_STATE_DIR="$sttab" MAPE_POLICY="$poltab" bash "$MAPE_DIR/efficacy.sh" >/dev/null 2>&1; spy=$(awk -F'\t' '$1=="セキュリティ 強化"{print $2}' "$sttab/efficacy.tsv" 2>/dev/null)
  { [ "$sjq" = "$spy" ] && [ "$sjq" = 3 ]; } && ok "efficacy: item タブを両経路で正規化しテーマ帰属が一致（samples=$sjq）" || ng "efficacy: タブでバックエンド相違（jq=$sjq py=$spy）"
  rm -rf "$sttab" "$sbTA" "$sbTB"
fi

# ---------------------------------------------------------------------------
sec "31. run.sh: safe-state を毎周回リフレッシュし stale な safe.env=1 を信用しない（NFR-SAFE-002 / fail-open 回帰）"
# Verifies: NFR-SAFE-002
rr="$TMP/rr"; rm -rf "$rr"; mkdir -p "$rr/mape/state"
for s in lib.sh monitor.sh analyze.sh plan.sh run.sh efficacy.sh circuit-breaker.sh; do ln -s "$MAPE_DIR/$s" "$rr/mape/$s"; done
# safe-state.sh を「安全でも危険でも safe.env を一切書かない」スタブに差し替える（＝評価失敗の再現）
printf '#!/usr/bin/env bash\nexit 0\n' > "$rr/mape/safe-state.sh"; chmod +x "$rr/mape/safe-state.sh"
cp -r knowledge "$rr/knowledge"
( cd "$rr" && git init -q && git -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1 && git checkout -qb feature/x )
printf 'MAPE_SAFE=1\nMAPE_SAFE_REASONS=stale-previous-run\n' > "$rr/mape/state/safe.env"   # 前周回の古い値
MAPE_NO_GATE=1 MAPE_STATE_DIR="$rr/mape/state" bash "$rr/mape/run.sh" >/dev/null 2>&1
sv=$(grep -E '^MAPE_SAFE=' "$rr/mape/state/safe.env" | tail -1 | cut -d= -f2-)
[ "$sv" = 0 ] && ok "run.sh: 評価前に safe.env を unsafe へリセット（stale=1 を残さない）" || ng "run.sh: 古い safe.env=$sv を信用（fail-open）"
grep -qF 'safe-state=0' "$rr/mape/state/issue-body.md" 2>/dev/null && ok "run.sh: safe-state 未評価周回は Execute 抑止バナーを掲示" || ng "run.sh: unsafe なのに抑止バナーなし（fail-open）"
rm -rf "$rr"

# ---------------------------------------------------------------------------
sec "32. 先頭ハイフンの提案テキストで grep がオプション誤認せず二重追記しない（[4/22] 回帰）"
tk=$(mktemp -d); cp "$MAPE_POLICY" "$MAPE_HEALTH" "$tk/" 2>/dev/null
# 本文が `-` で始まる候補（例: `-flag を外す`）。step5 の永続化 dedup grep が `-…` をオプション誤認すると
# 「未検出」に倒れて毎周回で再追記＝BACKLOG が無限に膨らむ。
printf '# B\n## 候補\n- [ ] (P2, approve) -flag を外す — t\n## アーカイブ\n' > "$tk/BACKLOG.md"
printf 'MAPE_GATE=pass\nMAPE_CYCLE=1\nMAPE_TS=t\nMAPE_GATE_S=1\nMAPE_TODO=0\nMAPE_SCRIPTS=1\nMAPE_MAX_SKILL=1\nMAPE_CLAUDE_MD=1\nMAPE_ADR=1\nMAPE_CHURN_TOP=-\nMAPE_STALE_H=-\n' > "$MAPE_STATE_DIR/monitor.env"
: > "$MAPE_STATE_DIR/ledger.jsonl"
MAPE_STATE_DIR="$MAPE_STATE_DIR" MAPE_KNOWLEDGE_DIR="$tk" bash "$MAPE_DIR/analyze.sh" --update-knowledge >/dev/null 2>&1
n=$(grep -cF -- '-flag を外す' "$tk/BACKLOG.md")
[ "$n" -le 1 ] && ok "先頭 - の候補を二重追記しない（$n 件）" || ng "先頭 - の候補が二重追記された（$n 件・grep オプション誤認）"
rm -rf "$tk"; rm -f "$MAPE_STATE_DIR/ledger.jsonl"

# ---------------------------------------------------------------------------
sec "33. nightly ワークフローの安全契約と起動方式（ADR-0019 → ADR-0023 で手動起動のみ）"
nw="$REPO/.github/workflows/mape-nightly.yml"
[ -f "$nw" ] && ok "nightly: ワークフローが存在" || ng "nightly: ワークフロー未配置"
if [ -f "$nw" ]; then
  grep -qF 'mape/run.sh --record' "$nw" && ok "nightly: 決定論 M→A→P（--record）を実走" || ng "nightly: run.sh --record を呼ばない"
  grep -qF -- '--draft' "$nw" && ok "nightly: ドラフト PR で提出（無人マージ禁止）" || ng "nightly: ドラフト PR でない"
  grep -qF 'main|master)' "$nw" && ok "nightly: 保護ブランチ名を拒否するガードがある" || ng "nightly: 保護ブランチガードなし"
  # main/master へ直接 push する行が無い（絶対原則）
  grep -qE 'push[^\n]*origin[[:space:]]+(main|master)([^A-Za-z0-9_-]|$)' "$nw" && ng "nightly: main/master へ直接 push する行がある（禁止）" || ok "nightly: main/master への直接 push なし"
  # 壊しうる Execute（実装）をワークフローで実行しない（PR 本文の説明的言及は除く: 実行行のみ検査）
  grep -qE '^[[:space:]]*(run:|-)[^\n]*circuit-breaker\.sh[[:space:]]+record' "$nw" && ng "nightly: Execute の record を実行（読み取り専用に反する）" || ok "nightly: 壊しうる Execute を実行しない（読み取り専用）"
  # permissions は PR 作成まで（列挙外は落ちる）
  grep -qF 'pull-requests: write' "$nw" && ok "nightly: PR 作成権限を明示（bounded permissions）" || ng "nightly: permissions が不明"
  # ADR-0023: 夜間 cron は止めた。手動起動口だけを残す（cron が黙って戻るのを防ぐ）。
  # コメント中の "cron" は許すが、YAML キーとしての schedule/cron 行は無いこと。
  grep -qE '^[[:space:]]*schedule:' "$nw" && ng "nightly: schedule: が復活している（ADR-0023 は手動起動のみ。戻すなら新 ADR）" || ok "nightly: 自動スケジュールを持たない（ADR-0023）"
  grep -qE '^[[:space:]]*-[[:space:]]*cron:' "$nw" && ng "nightly: cron: 行が復活している（ADR-0023 は手動起動のみ。戻すなら新 ADR）" || ok "nightly: cron 行を持たない（ADR-0023）"
  grep -qE '^[[:space:]]*workflow_dispatch:' "$nw" && ok "nightly: 手動起動口が残っている（workflow_dispatch）" || ng "nightly: 手動起動口が無い（起動手段が消える）"
fi

# ---------------------------------------------------------------------------
echo
echo "mape/tests: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || { echo "mape テスト失敗" >&2; exit 1; }
echo "mape テスト合格"
