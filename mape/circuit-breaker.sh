#!/usr/bin/env bash
# @file mape/circuit-breaker.sh
# @brief ガードレール — サーキットブレーカー ＆ 実行台帳（ledger）。ADR-0010。
# @description
#   Execute の各試行を $MAPE_STATE_DIR/ledger.jsonl に追記し、危険な連鎖を検知して停止させる。
#
#   使い方:
#     bash mape/circuit-breaker.sh status                     # ok なら exit 0 / 停止条件なら exit 3
#     bash mape/circuit-breaker.sh record <green|red> <item> [pr] [branch]
#     bash mape/circuit-breaker.sh done <item>               # 実装済み(green)なら exit 0（冪等性クエリ）
#     bash mape/circuit-breaker.sh quarantine <item> [reason] # 毒項目を隔離（全停止回避。ADR-0015）
#     bash mape/circuit-breaker.sh reset                      # 台帳を退避してブレーカーを解除
#
#   停止条件（POLICY 相当。環境変数で調整可能。lib.sh 参照）:
#     - 末尾が連続 red で MAPE_CB_CONSECUTIVE_FAIL 件に達した
#     - 同一 item の red が MAPE_CB_SAME_ITEM_FAIL 回に達した
#     - 直近 MAPE_CB_REVERT_WINDOW 件のうち red が MAPE_CB_REVERT_MAX 件以上
#
#   フェイルセーフの向き: 末尾連続 red と直近 window red は item 非依存の GLOBAL 暴走停止であり、
#   隔離（ADR-0015）でも cooldown でも決して解除しない。JSON パーサが皆無で暴走を検証できないときは
#   ok（exit 0）ではなく **安全側の exit 4**（状態不明）を返す。record だけは記録欠落＝ブレーカーの
#   盲目化を招くため、パーサ皆無でも手組み JSON で必ず追記する。
#
# @arg $1 string サブコマンド（status|record|done|quarantine|reset。既定 status）
# @arg $2 string record: green|red ／ done・quarantine: item
# @arg $3 string record: item ／ quarantine: reason（任意）
# @arg $4 string record: PR 番号（任意）
# @arg $5 string record: ブランチ名（任意）
# @stdout status: `ok: …` / `tripped: <理由>`
# @stderr `[mape] …` の進行ログ・破損行の警告
# @exitcode 0 status=ok／done=実装済み／record・quarantine・reset の正常終了
# @exitcode 1 引数不正（mape_die）／done=未実装
# @exitcode 3 status=tripped（暴走検知。Execute を止める）
# @exitcode 4 status=判定不能（JSON パーサ不在。安全側で停止。safe-state は unsafe へ畳む）
# @see docs/adr/0015-mape-k-item-quarantine-and-bounded-breaker-recovery.md
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mape_ensure_state
ledger="$MAPE_STATE_DIR/ledger.jsonl"

cmd="${1:-status}"

case "$cmd" in
  record)
    result="${2:-}"; item="${3:-}"; pr="${4:-}"; branch="${5:-}"
    [ "$result" = "green" ] || [ "$result" = "red" ] || mape_die "result は green|red"
    [ -n "$item" ] || mape_die "item が必要"
    ts=$(mape_now)
    if command -v jq >/dev/null 2>&1; then
      jq -cn --arg ts "$ts" --arg item "$item" --arg result "$result" --arg pr "$pr" --arg branch "$branch" \
        '{ts:$ts,item:$item,result:$result,pr:$pr,branch:$branch}' >> "$ledger"
    elif command -v python3 >/dev/null 2>&1; then
      python3 - "$ts" "$item" "$result" "$pr" "$branch" >> "$ledger" <<'PY'
import json,sys
ts,item,result,pr,branch=sys.argv[1:6]
print(json.dumps({"ts":ts,"item":item,"result":result,"pr":pr,"branch":branch},ensure_ascii=False))
PY
    else
      # パーサ皆無のフェイルセーフ: 最小エスケープで JSON を手組みして追記する。記録を落とすと
      # ブレーカーが失敗を観測できず「盲目」になる（暴走を止められない）ため、追記だけは必ず行う。
      # バックスラッシュ→"→改行/タブ の順にエスケープ/除去（JSONL の1行不変条件を守る）。
      # @internal
      # @description JSON 文字列値として安全な形へ最小エスケープする（パーサ皆無時の手組み JSON 用）。
      # @arg $1 string エスケープ対象の生文字列
      # @stdout `\` と `"` をエスケープし、制御文字を空白へ潰した文字列
      # @exitcode 0 常に成功
      esc() { printf '%s' "$1" | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/[[:cntrl:]]/ /g'; }
      printf '{"ts":"%s","item":"%s","result":"%s","pr":"%s","branch":"%s"}\n' \
        "$(esc "$ts")" "$(esc "$item")" "$result" "$(esc "$pr")" "$(esc "$branch")" >> "$ledger"
    fi
    mape_log "ledger 追記: $result — $item"
    ;;

  status)
    [ -f "$ledger" ] || { echo "ok: 台帳が空（試行なし）"; exit 0; }
    # 生カウントは JSON パーサ（python3 優先→jq フォールバック→無ければフェイルセーフ ok）で行い、
    # トリップ *判定* は bash 側で下す。理由: 同一項目の暴走判定に「隔離(## ブロック中)なら除外」という
    # 自己修復ゲート（ADR-0015）を挟むため。**末尾連続 red・直近window red は GLOBAL 暴走の最終防壁として
    # 隔離でも cooldown でも絶対に解除しない**（trail/winred は item 非依存で常に効く）。
    # カウンタは stdout="trail winred count"、$reds に赤の item別回数（count\titem）を書く。破損行は警告し除外。
    reds="$MAPE_STATE_DIR/.cb_reds"; : > "$reds"
    if command -v python3 >/dev/null 2>&1; then
      set -- $(python3 - "$ledger" "$MAPE_CB_REVERT_WINDOW" "$reds" <<'PY'
import json,sys
path,win,redsf=sys.argv[1],int(sys.argv[2]),sys.argv[3]
rows=[]; bad=0
# errors="replace": 不正 UTF-8 で読み取り自体がクラッシュしないよう置換（フェイルセーフ）。
# JSON パースが通っても **オブジェクト以外（数値・文字列・配列）は捨てる**。さもないと後段の
# r.get() が非オブジェクトで AttributeError を起こし、集計が空になり暴走停止(trail/winred)を握り潰す。
for ln in open(path,encoding="utf-8",errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: o=json.loads(ln)
    except Exception: bad+=1; continue
    if not isinstance(o,dict): bad+=1; continue
    rows.append(o)
if bad:
    sys.stderr.write(f"[mape] 警告: ledger に不正な行が {bad} 行あります（無視して集計。手動修正/reset を検討）\n")
trail=0
for r in reversed(rows):
    if r.get("result")=="red": trail+=1
    else: break
from collections import Counter
# item が文字列の red のみ同一項目カウント（item がオブジェクト/配列だと unhashable で Counter が落ちる）。
c=Counter(r.get("item") for r in rows if r.get("result")=="red" and isinstance(r.get("item"),str))
with open(redsf,"w",encoding="utf-8") as f:
    for it,n in c.items():
        if it is None: continue
        f.write(f"{n}\t{it}\n")
win_red=sum(1 for r in rows[-win:] if r.get("result")=="red")
print(trail,win_red,len(rows))
PY
)
    elif command -v jq >/dev/null 2>&1; then
      # select(type=="object"): 非オブジェクト行（数値・文字列・配列）を valid から除外する。
      # 残すと下の `.result`/`.item` アクセスで jq が全体エラーになり集計が空＝暴走停止を握り潰す。
      valid=$(while IFS= read -r line; do [ -z "$line" ] && continue; printf '%s\n' "$line" | jq -c 'select(type=="object")' 2>/dev/null; done < "$ledger")
      nonempty=$(grep -cvE '^[[:space:]]*$' "$ledger" 2>/dev/null || true); nonempty=${nonempty:-0}
      nvalid=$(printf '%s\n' "$valid" | grep -c . 2>/dev/null || true); nvalid=${nvalid:-0}
      [ "$(( nonempty - nvalid ))" -gt 0 ] && echo "[mape] 警告: ledger に不正な行が $(( nonempty - nvalid )) 行あります（無視して集計）" >&2
      # .item が文字列の red のみ同一項目カウント（python3 経路 line 107 の isinstance str と揃える。
      # 揃えないと item がオブジェクト/配列の行を jq だけ数え、同一項目トリップ判定がバックエンド依存になる）。
      printf '%s\n' "$valid" | jq -s -r 'map(select(.result=="red" and (.item|type=="string")))|group_by(.item)|map("\(length)\t\(.[0].item)")[]' 2>/dev/null > "$reds"
      set -- $(printf '%s\n' "$valid" | jq -s -r --argjson win "$MAPE_CB_REVERT_WINDOW" '
        def trail: (reverse | reduce .[] as $r ({n:0,s:false}; if .s then . elif ($r.result=="red") then {n:(.n+1),s:false} else {n:.n,s:true} end)).n;
        (.[-$win:] | map(select(.result=="red")) | length) as $winred
        | "\(trail) \($winred) \(length)"' 2>/dev/null)
    else
      # パーサ皆無では暴走（末尾連続/同一項目/直近window red）を検証できない。ここで ok(exit 0) を
      # 返すと safe-state が「ブレーカー非tripped」と誤認し、暴走台帳の上で無人 Execute を許可して
      # しまう（fail-open・invariant(d) 反転）。判定不能は **安全側=非0** で返す（exit 4）。
      # 3（tripped）とは区別する: safe-state は 0/3 以外を「状態不明→unsafe」に畳む。
      echo "指標不明: JSON パーサ（python3/jq）が無く暴走判定不能（安全側で停止）" >&2; exit 4
    fi
    trail=${1:-0}; winred=${2:-0}; count=${3:-0}
    # 同一項目の最大赤回数を求める。隔離済み(## ブロック中)は「再提案されない＝再発しない」と
    # 証明済みなので判定から除外する（有界な自己修復。cooldown 有効時のみ最小 dwell を課す）。
    same_n=0; same_item=""
    while IFS=$'\t' read -r n it; do
      [ -n "$n" ] && [ -n "$it" ] || continue
      if mape_is_quarantined "$it"; then
        if [ "${MAPE_CB_COOLDOWN_H:-0}" -gt 0 ] 2>/dev/null && ! mape_cooldown_elapsed; then :; else continue; fi
      fi
      [ "$n" -gt "$same_n" ] 2>/dev/null && { same_n=$n; same_item=$it; }
    done < "$reds"
    reasons=""
    [ "$trail" -ge "$MAPE_CB_CONSECUTIVE_FAIL" ] 2>/dev/null && reasons="末尾連続 red ${trail}件（>= ${MAPE_CB_CONSECUTIVE_FAIL}）"
    [ "$same_n" -ge "$MAPE_CB_SAME_ITEM_FAIL" ] 2>/dev/null && reasons="${reasons:+$reasons / }同一項目の red ${same_n}回（>= ${MAPE_CB_SAME_ITEM_FAIL}）: ${same_item}"
    [ "$winred" -ge "$MAPE_CB_REVERT_MAX" ] 2>/dev/null && reasons="${reasons:+$reasons / }直近window red ${winred}件（>= ${MAPE_CB_REVERT_MAX}）"
    tstamp="$MAPE_STATE_DIR/breaker.tripped_at"
    if [ -n "$reasons" ]; then
      [ -f "$tstamp" ] || mape_now > "$tstamp"     # 初回トリップ時刻（観測・cooldown 用）
      echo "tripped: $reasons"; exit 3
    fi
    rm -f "$tstamp"
    echo "ok: 試行${count}件 / 末尾連続red ${trail} / 直近window red ${winred}"; exit 0
    ;;

  quarantine)
    # 毒項目を「## ブロック中」へ隔離（自己修復。ADR-0015）。analyze は再提案せず、同一項目
    # トリップも自動クリアされる。GLOBAL 暴走停止（末尾連続/直近window）は隔離では解除されない。
    item="${2:-}"; reason="${3:-}"
    [ -n "$item" ] || mape_die "item が必要"
    mape_quarantine_add "$item" "$reason"
    ;;

  done)
    # 冪等性クエリ: 指定 item が台帳に green で存在すれば exit 0（＝実装済み・再実行不要）
    item="${2:-}"; [ -n "$item" ] || mape_die "item が必要"
    [ -f "$ledger" ] || exit 1
    if command -v jq >/dev/null 2>&1; then
      # 1行ずつ評価する（ストリーム全体を jq に渡すと不正な1行で中断し、以降の green を
      # 見落として実装済み項目を「未実装」と誤判定＝二重実行の原因になる）。
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf '%s\n' "$line" | jq -e --arg it "$item" 'select(.item==$it and .result=="green")' >/dev/null 2>&1 && exit 0
      done < "$ledger"
      exit 1
    elif command -v python3 >/dev/null 2>&1; then
      python3 - "$ledger" "$item" <<'PY'
import json,sys
path,item=sys.argv[1],sys.argv[2]
# errors="replace" で不正 UTF-8 でも読み取りを継続。非オブジェクト行は isinstance で弾く
# （非オブジェクトに .get すると AttributeError で落ち、後続の green を見落とす＝二重実行）。
for ln in open(path,encoding="utf-8",errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: r=json.loads(ln)
    except Exception: continue
    if isinstance(r,dict) and r.get("item")==item and r.get("result")=="green": sys.exit(0)
sys.exit(1)
PY
    else
      exit 1   # パーサ皆無 → 実装済み判定不能 → 未実装扱い（安全側。再実行しても breaker が守る）
    fi
    ;;

  reset)
    if [ -f "$ledger" ]; then
      bak="$ledger.$(date -u +%Y%m%dT%H%M%SZ).bak"
      mv "$ledger" "$bak"
      mape_log "台帳を $bak に退避してブレーカーを解除"
    else
      mape_log "台帳は空。解除不要"
    fi
    rm -f "$MAPE_STATE_DIR/breaker.tripped_at" "$MAPE_STATE_DIR/.cb_reds"
    ;;

  *)
    mape_die "未知のコマンド: $cmd（status|record|done|quarantine|reset）"
    ;;
esac
