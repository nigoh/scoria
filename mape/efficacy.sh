#!/usr/bin/env bash
# @file mape/efficacy.sh
# @brief 効き目感知（self-optimization） — 委託台帳から重点テーマごとの「効き目」を学習する。ADR-0014 / ADR-0017。
# @description
#   細胞は自分の行動が効いたかを覚えて次の優先度を調律する。ここでは Execute の実績（committed な
#   ledger.jsonl の green/red）を POLICY の重点テーマへ帰属させ、テーマ別の効き目 efficacy.tsv を書く。
#   Analyze の mape_effectiveness_factor がこれを読み、効いているテーマの提案を加点・効いていない
#   テーマを減点する（採点のみ・tier は不変。安全境界。NFR-OPT-001）。read-only・非破壊（台帳は読むだけ）。
#
#   出力: $MAPE_STATE_DIR/efficacy.tsv（TSV: theme \t samples \t improved(green) \t worsened(red) \t status）
#     status: improved（red 皆無）/ worsened（red が green 以上）/ neutral（それ以外・またはサンプル<3）
#   台帳は committed（夜をまたいで dur  な記憶）だが efficacy.tsv は台帳から再計算できる派生物＝gitignore。
#
#   パーサ（python3→jq→無ければフェイルセーフで何も書かず終了＝中立）で `result\titem` を取り出し、
#   テーマ帰属（mape_theme_of。POLICY 依存）は bash 側で一元化してから awk で集計する。破損行は無視して継続。
#
# @noargs
# @stderr `[mape] efficacy: N テーマの効き目を更新`
# @exitcode 0 常に成功（台帳不在・パーサ不在でも空の efficacy.tsv を残して中立で終わる）
# @see mape_effectiveness_factor
# @see docs/adr/0017-mape-k-efficacy-feedback-self-optimization.md
set -u
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mape_ensure_state
ledger="$MAPE_STATE_DIR/ledger.jsonl"
out="$MAPE_STATE_DIR/efficacy.tsv"

# 台帳が無ければ効き目は未知＝中立。空の efficacy.tsv を残す（factor は行が無ければ 10 を返す）。
[ -f "$ledger" ] || { : > "$out"; exit 0; }

# --- 台帳から (result, item) を取り出す。破損行は無視。パーサが無ければ中立で終了 ---
# @internal
# @description 台帳 $ledger から `result<TAB>item` を取り出す。green/red 以外・非文字列 item は捨てる。
#   python3 経路と jq 経路は同一入力で同一出力になるよう揃えてある（非オブジェクト行の除外・
#   item 内タブ/改行の空白正規化）。揃えないとインストール済みパーサ次第でテーマ帰属と採点が変わる。
# @noargs
# @stdout `<green|red><TAB><item>` の行（有効な実績の件数だけ）
# @exitcode 0 パーサが走った（結果が空でも 0。空は「実績なし」であって「判定不能」ではない）
# @exitcode 3 フェイルセーフ: JSON パーサ（python3/jq）が無く判定不能 → 呼び出し側は中立で打ち切る
extract() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ledger" <<'PY'
import json,sys
# errors="replace" で不正 UTF-8 でも読み取り継続。非オブジェクト行は isinstance で弾く
# （非オブジェクトに .get すると AttributeError で落ち、その行以降の有効行を全て取りこぼす）。
for ln in open(sys.argv[1],encoding="utf-8",errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: r=json.loads(ln)
    except Exception: continue
    if not isinstance(r,dict): continue
    res=r.get("result",""); item=r.get("item","")
    # item は文字列のみ扱う（数値/オブジェクト等は jq 経路が gsub で弾くのに合わせる。バックエンド一致）。
    if res in ("green","red") and isinstance(item,str) and item:
        print(res+"\t"+item.replace("\t"," ").replace("\n"," "))
PY
    return 0
  elif command -v jq >/dev/null 2>&1; then
    # 1行ずつ評価する（ストリーム全体を jq に渡すと不正な1行で中断し以降を取りこぼす）。
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # .item のタブ/改行を空白へ正規化する（python3 経路の str.replace と挙動を揃える）。
      # 揃えないと item にタブを含む台帳で jq 経路だけ TSV の列がずれ、テーマ帰属/効き目/採点が
      # バックエンド依存になる。
      printf '%s\n' "$line" | jq -r 'select((.result=="green" or .result=="red") and (.item|type=="string") and .item!="")|"\(.result)\t\(.item|gsub("[\\t\\n]";" "))"' 2>/dev/null
    done < "$ledger"
    return 0   # while は EOF で read が非0を返すため明示的に成功を返す（さもないと下の fail-safe が誤発火）
  else
    return 3   # フェイルセーフ: パーサ無し
  fi
}

# extract が return 3（パーサ無し）のときだけ中立で打ち切る。パーサが走った結果が空なら通常処理を続ける。
pairs=$(extract) || { : > "$out"; exit 0; }

# --- テーマへ帰属（POLICY 依存の mape_theme_of で一元化）→ `theme\tresult` を集計へ流す ---
{
  while IFS=$'\t' read -r result item; do
    [ -n "$result" ] && [ -n "$item" ] || continue
    theme=$(mape_theme_of "$item")
    [ -n "$theme" ] || continue   # 重点テーマに帰属しない実績は効き目に数えない（ノイズ源を断つ）
    printf '%s\t%s\n' "$theme" "$result"
  done <<EOF
$pairs
EOF
} | awk -F'\t' '
  { th=$1; r=$2; if (!(th in seen)) { seen[th]=1; order[++k]=th } if (r=="green") g[th]++; else if (r=="red") b[th]++ }
  END {
    for (i=1;i<=k;i++) {
      th=order[i]; gc=g[th]+0; bc=b[th]+0; smp=gc+bc;
      if (smp<3)        st="neutral";     # 標本が薄いうちは断定しない（factor も <3 は中立）
      else if (bc==0)   st="improved";    # red 皆無＝この種の仕事は定着している
      else if (bc>=gc)  st="worsened";    # red が green 以上＝この種の仕事は回帰しがち
      else              st="neutral";
      printf "%s\t%d\t%d\t%d\t%s\n", th, smp, gc, bc, st;
    }
  }' > "$out"

mape_log "efficacy: $(grep -c . "$out" 2>/dev/null || echo 0) テーマの効き目を更新"
