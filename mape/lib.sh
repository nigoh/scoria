#!/usr/bin/env bash
# @file mape/lib.sh
# @brief MAPE-K 共有ライブラリ。すべての mape スクリプトが source して使い、単体では実行しない（ADR-0010）。
# @description
#   すべての mape スクリプトが読み込む共通関数と設定。
#
#   設計の約束:
#    - スクリプトは既定で「読み取り専用」= 書き込みは $MAPE_STATE_DIR 配下のみ。
#      knowledge/ を変更するのは --record / --update-knowledge を渡したときだけ。
#    - $MAPE_STATE_DIR は環境変数で差し替え可能（テストは一時ディレクトリを指す）。
#
#   ここで定義する `mape_*` 関数は他の mape スクリプト・テストから使われる公開 API 相当。
#   安全機構（ブレーカー・隔離・整合性検査）に関わる関数は、情報が欠けたときの倒れる向き
#   （fail-closed か fail-safe か）を各関数の @description に明記してある。
#
# @set MAPE_ROOT string リポジトリルート（このファイルの1つ上）。export 済み
# @set MAPE_STATE_DIR string 中間成果物の置き場。既定 $MAPE_ROOT/mape/state（テストで差し替え可能）
# @set MAPE_KNOWLEDGE_DIR string 知識ディレクトリ。既定 $MAPE_ROOT/knowledge
# @set MAPE_POLICY string POLICY.md のパス（分類キーワード・却下ログ・setpoints・重点テーマ）
# @set MAPE_HEALTH string HEALTH.md のパス（推移表）
# @set MAPE_BACKLOG string BACKLOG.md のパス（候補・ブロック中）
# @set MAPE_PROGRESS string PROGRESS.md のパス（周回ログ）
# @see docs/adr/0010-mape-k-nighttime-self-improvement.md

# リポジトリルート（このファイルの1つ上）
MAPE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAPE_ROOT="$(cd "$MAPE_LIB_DIR/.." && pwd)"
export MAPE_ROOT

# 中間成果物の置き場（テストで差し替え可能）
MAPE_STATE_DIR="${MAPE_STATE_DIR:-$MAPE_ROOT/mape/state}"
export MAPE_STATE_DIR

# 知識ファイル
MAPE_KNOWLEDGE_DIR="${MAPE_KNOWLEDGE_DIR:-$MAPE_ROOT/knowledge}"
export MAPE_KNOWLEDGE_DIR
MAPE_POLICY="${MAPE_POLICY:-$MAPE_KNOWLEDGE_DIR/POLICY.md}"
MAPE_HEALTH="$MAPE_KNOWLEDGE_DIR/HEALTH.md"
MAPE_BACKLOG="$MAPE_KNOWLEDGE_DIR/BACKLOG.md"
MAPE_PROGRESS="$MAPE_KNOWLEDGE_DIR/PROGRESS.md"

# サーキットブレーカーの閾値（POLICY で上書きしたくなったら環境変数で）
MAPE_CB_CONSECUTIVE_FAIL="${MAPE_CB_CONSECUTIVE_FAIL:-3}"   # 直近が連続 fail でこの数に達したら停止
MAPE_CB_SAME_ITEM_FAIL="${MAPE_CB_SAME_ITEM_FAIL:-2}"       # 同一項目がこの回数 fail したら停止
MAPE_CB_REVERT_WINDOW="${MAPE_CB_REVERT_WINDOW:-5}"          # 直近この件数を見る
MAPE_CB_REVERT_MAX="${MAPE_CB_REVERT_MAX:-3}"                # そのうち revert がこの数以上で停止
MAPE_STALE_MAX_H="${MAPE_STALE_MAX_H:-36}"                   # HEALTH 最終追記からこの時間で「休眠」提案（ADR-0014）
MAPE_CB_COOLDOWN_H="${MAPE_CB_COOLDOWN_H:-0}"                # >0 で隔離クリアに最小 dwell を課す（0=即時。ADR-0015）

# @description 進行状況を stderr へ出す（stdout は成果物用に空けておくため）。
# @arg $@ string ログ本文
# @stderr `[mape] <本文>`
# @exitcode 0 常に成功
mape_log() { printf '[mape] %s\n' "$*" >&2; }

# @description 致命的エラーを stderr へ出してプロセスを終了する。
# @arg $@ string エラー本文
# @stderr `[mape] ERROR: <本文>`
# @exitcode 1 常に（呼び出し元スクリプトごと終了する）
mape_die() { printf '[mape] ERROR: %s\n' "$*" >&2; exit 1; }

# @description 決定論的な UTC タイムスタンプ（ワークフロー JS の Date 制限は bash には無い）。
#   形式は 'YYYY-MM-DDTHH:MMZ' で、mape_epoch_utc が解釈できる唯一の形式。
# @noargs
# @stdout UTC タイムスタンプ（例 2026-07-30T02:15Z）
# @exitcode 0 成功
mape_now() { date -u +%Y-%m-%dT%H:%MZ; }

# @description 中間成果物ディレクトリ（$MAPE_STATE_DIR）を作る。書き込み前に必ず呼ぶ。
# @noargs
# @exitcode 0 作成済み／作成成功
# @exitcode 1 mkdir 失敗
mape_ensure_state() { mkdir -p "$MAPE_STATE_DIR"; }

# @description monitor.env を安全に読み込む（ADR-0010。セキュリティ: `. file` で source しない）。
#   理由: 値（例 MAPE_CHURN_TOP）はリポジトリ内のファイル名など外部制御データ由来で、
#   source すると `名前;$(cmd)` のようなファイルで無人ループがコマンド実行し得る。
#   ここでは許可キーのみを「リテラル代入」する（コマンド置換・評価を一切行わない）。
#   未知キーは黙って無視する（許可リスト方式＝新キーは明示追加が必要）。
# @arg $1 string 読み込む env ファイルのパス（不在なら何もしない）
# @set MAPE_TS string monitor が記録した UTC タイムスタンプ
# @set MAPE_CYCLE string 周回番号
# @set MAPE_GATE string 品質ゲートの結果（pass|fail|skip）
# @set MAPE_GATE_S string 品質ゲートの所要秒（未計測は '-'）
# @set MAPE_TODO string TODO/FIXME マーカー件数
# @set MAPE_SCRIPTS string シェルスクリプト数
# @set MAPE_MAX_SKILL string 最長 SKILL.md の行数
# @set MAPE_CLAUDE_MD string CLAUDE.md の行数
# @set MAPE_ADR string ADR 数
# @set MAPE_CHURN_TOP string churn 首位ファイル名（無毒化済み）
# @set MAPE_STALE_H string 最終 HEALTH 追記からの経過時間(h)。判定不能は '-'
# @exitcode 0 常に成功（ファイル不在も成功扱い）
mape_load_env() {
  local file="$1" k v
  [ -f "$file" ] || return 0
  while IFS='=' read -r k v; do
    case "$k" in
      MAPE_TS|MAPE_CYCLE|MAPE_GATE|MAPE_GATE_S|MAPE_TODO|MAPE_SCRIPTS|MAPE_MAX_SKILL|MAPE_CLAUDE_MD|MAPE_ADR|MAPE_CHURN_TOP|MAPE_STALE_H)
        printf -v "$k" '%s' "$v" ;;   # $v はリテラル。eval しない
      *) : ;;                          # 未知キーは無視
    esac
  done < "$file"
}

# @description POLICY.md の「### <tier>」見出し直後の ``` フェンス内キーワードを1行ずつ出力する。
#   人間が POLICY.md を編集するだけで、コードを触らずにリスク分類の語彙を調律できる。
# @arg $1 string tier 名（consult|approve|auto）
# @stdout キーワード（1行1件）。POLICY 不在／見出し不在なら無出力
# @exitcode 0 常に成功
mape_policy_keywords() {
  local tier="$1"
  [ -f "$MAPE_POLICY" ] || return 0
  awk -v t="$tier" '
    $0 ~ ("^### " t) { found=1; infence=0; next }
    found && /^```/   { if (infence) { exit } else { infence=1; next } }
    found && infence  { print }
  ' "$MAPE_POLICY"
}

# @description 自己設定（ADR-0014 §27）: POLICY「## 今月の重点テーマ」直下の箇条書きを1行1テーマで出力する
#   （mape_setpoints と同型の見出し→行抽出。（…）注釈は落とす）。装飾だった重点テーマを analyze が読む。
# @noargs
# @stdout 重点テーマ（1行1件）。POLICY 不在／見出し不在なら無出力
# @exitcode 0 常に成功
# @see mape_theme_of
mape_themes() {
  [ -f "$MAPE_POLICY" ] || return 0
  awk '
    /^## 今月の重点テーマ/ { found=1; next }
    found && /^## /        { exit }
    found && /^- /         { sub(/^- /,""); sub(/（.*/,""); gsub(/[[:space:]]+$/,""); if (length>0) print }
  ' "$MAPE_POLICY"
}

# @description text が能動テーマに一致すればそのテーマ文字列を返す（無ければ空）。substring 一致（grep -qiF＝
#   固定文字列・ロケール非依存。既存 mape_classify と同じ照合）。テーマ文は簡潔なキーワード前提。
# @arg $1 string 照合する提案テキスト
# @stdout 最初に一致した重点テーマ文字列。非該当／POLICY 不在は空
# @exitcode 0 常に成功（一致有無は stdout で表す）
mape_theme_of() {
  local text="$1" line
  [ -f "$MAPE_POLICY" ] || return 0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if printf '%s' "$text" | grep -qiF -- "$line"; then printf '%s' "$line"; return 0; fi
  done < <(mape_themes)
  return 0
}

# @description 能動テーマ一致なら有界な加点(+3)、非該当なら0。フラット（複数テーマ一致でも積み増さない＝bounded）。
# @arg $1 string 照合する提案テキスト
# @stdout 3（テーマ該当）または 0（非該当）
# @exitcode 0 常に成功
mape_theme_boost() { [ -n "$(mape_theme_of "$1")" ] && printf 3 || printf 0; }

# @description 効き目に基づく有界な可変係数（ADR-0014 §30。÷10 して使う）。efficacy.tsv（§29 が生成）を読む。
#   improved→12 / neutral→10 / worsened→7。samples<3（コールドスタート）は neutral(10)。行なし/空テーマも10。
#   係数は [7,12] にクランプ（壊れた status も安全側 10 経由でクランプ）。mape_score は変えない・並べ替えのみ。
#   有界にしてあるのは、学習が暴走して tier や Execute 条件を実質的に書き換えないようにするため。
# @arg $1 string 重点テーマ文字列（空なら中立の 10）
# @stdout 係数（7〜12 の整数。使う側で ÷10 する）
# @exitcode 0 常に成功
# @see mape/efficacy.sh
mape_effectiveness_factor() {
  local theme="$1" eff="$MAPE_STATE_DIR/efficacy.tsv" f
  [ -n "$theme" ] || { printf 10; return 0; }
  [ -f "$eff" ]   || { printf 10; return 0; }
  f=$(awk -F'\t' -v t="$theme" '
    $1==t { smp=$2+0; st=$5;
      if (smp<3)              { print 10; found=1; exit }
      if (st=="improved")       print 12;
      else if (st=="worsened")  print 7;
      else                      print 10;
      found=1; exit }
    END { if (!found) print 10 }' "$eff")
  case "$f" in ''|*[!0-9]*) f=10;; esac
  [ "$f" -lt 7 ]  && f=7
  [ "$f" -gt 12 ] && f=12
  printf '%s' "$f"
}

# @description HEALTH の時系列から指標の微分（連続増減の向きと連長）を読む。細胞の恒常性は「今の値」だけでなく
#   「動いている向き」で先回りする（絶対値が band 内でも上昇が続けば早期警告）。read-only・非破壊。
#   列は awk -F'|' で gate_s=5 todo=6 scripts=7 max_skill=8 claude_md=9 adr=10（HEALTH の固定11列）。
# @arg $1 string 指標名（gate_s|todo|scripts|max_skill|claude_md|adr）
# @stdout "rising N" / "falling N" / "flat 1" / "unknown"（3行未満＝希薄でデータ不足）
# @exitcode 0 常に成功（HEALTH 不在・未知指標も "unknown" を返して継続）
# @see mape_band_status
mape_trend() {
  local metric="$1" col
  [ -f "$MAPE_HEALTH" ] || { printf 'unknown'; return 0; }
  case "$metric" in
    gate_s) col=5;; todo) col=6;; scripts) col=7;;
    max_skill) col=8;; claude_md) col=9;; adr) col=10;;
    *) printf 'unknown'; return 0;;
  esac
  awk -F'|' -v c="$col" '
    /^\| [0-9][0-9][0-9][0-9]-/ {
      v=$c; gsub(/[[:space:]]/,"",v);
      if (v ~ /^[0-9]+$/) { n++; val[n]=v+0 }
    }
    END {
      if (n<3) { print "unknown"; exit }
      curdir=0; streak=1;
      for (i=n; i>1; i--) {
        d = (val[i]>val[i-1]) ? 1 : (val[i]<val[i-1]) ? -1 : 0;
        if (i==n) curdir=d;
        if (d==curdir && d!=0) streak++; else break;
      }
      if (curdir>0)      print "rising " streak;
      else if (curdir<0) print "falling " streak;
      else               print "flat 1";
    }' "$MAPE_HEALTH"
}

# @description 提案テキストをリスク分類する（consult > approve > auto の危険側優先。既定 approve）。
#   走査順を consult→approve→auto に固定しているのが安全境界: 複数 tier のキーワードに当たる
#   提案は必ず最も危険な側へ倒れる（無人 Execute の対象から外れる方向）。
# @arg $1 string 分類する提案テキスト
# @stdout tier 名（consult|approve|auto）。どれにも当たらなければ approve
# @exitcode 0 常に成功
mape_classify() {
  local text="$1" tier kw
  for tier in consult approve auto; do
    while IFS= read -r kw; do
      [ -z "$kw" ] && continue
      if printf '%s' "$text" | grep -qiF -- "$kw"; then
        printf '%s' "$tier"; return 0
      fi
    done < <(mape_policy_keywords "$tier")
  done
  printf 'approve'
}

# @description POLICY.md「## 却下ログ」の "- pattern: <正規表現> — <理由>" にマッチするか（マッチ=却下）。
#   注意: 区切りの em-dash（—）は `[^—]` のような文字クラスで扱わない。C/POSIX ロケールでは
#   マルチバイト文字がバイト集合として解釈され、`…`/`→` 等を含むパターンが誤切り詰めされるため、
#   「` —` 以降を除く」リテラル置換で理由部を落とす（バイト列リテラルはロケール非依存）。
# @arg $1 string 判定する提案テキスト
# @exitcode 0 却下パターンにマッチした（＝この提案は掲示しない）
# @exitcode 1 マッチしない／POLICY 不在
# @see mape_verify_knowledge POLICY の pattern が有効な正規表現かを検査する
mape_is_rejected() {
  local text="$1" pat
  [ -f "$MAPE_POLICY" ] || return 1
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    if printf '%s' "$text" | grep -qiE -- "$pat"; then return 0; fi
  done < <(grep -E '^- pattern:' "$MAPE_POLICY" 2>/dev/null \
            | sed -E 's/^- pattern:[[:space:]]*//' \
            | sed 's/[[:space:]]*—.*$//' \
            | sed -E 's/[[:space:]]+$//')
  return 1
}

# @description インパクト(1-5) と 労力(1-5) からスコアを出す（高インパクト・低労力ほど高い。範囲 1-25）。
#   非数値・範囲外（<1 または >5）は 3 に矯正する。上限を矯正しないと effort>5 で負スコアになり
#   proposals の並び（sort -k5,5nr）が壊れるため、下限だけでなく上限も必ずクランプする。
#   純粋関数（外部状態を読まない）。テーマ加点・効き目係数は analyze 側で合成する。
# @arg $1 int インパクト 1-5（不正値は 3 に矯正）
# @arg $2 int 労力 1-5（不正値は 3 に矯正）
# @stdout スコア（1-25 の整数）
# @exitcode 0 常に成功
mape_score() {
  local impact="$1" effort="$2"
  { [ "$impact" -ge 1 ] && [ "$impact" -le 5 ]; } 2>/dev/null || impact=3
  { [ "$effort" -ge 1 ] && [ "$effort" -le 5 ]; } 2>/dev/null || effort=3
  echo $(( impact * (6 - effort) ))
}

# @description 外部制御データ（churn 由来のファイル名など、ブランチに commit した者が中身を決められる値）を、
#   人間が読む monitor.md／計画イシュー（issue-body.md）／**無人 Execute LLM** の文脈へ入れる前に
#   無毒化する。狙い: (a) markdown/HTML メタ文字で計画イシューを壊さない (b) 計画を読み込んで
#   コードを書き PR を開く無人エージェントへのプロンプトインジェクションを断つ（ADR-0010 の膜を塞ぐ）。
#   除去: バッククォート・[ ]・< >・|・バックスラッシュ（md/html/表の構造メタ文字）と制御文字。
#   改行/タブは空白へ潰す（別行に見せかけた見出し・指示の注入を防ぐ）。最後に 80 字へ丸める。
#   ファイル名に多い英数・/・.・-・_・* は温存する（表示忠実性）。LC_ALL=C はマルチバイト誤爆回避。
#   多層防御なので、monitor で無毒化済みの値でも下流（analyze/run）で再度通してよい（冪等）。
# @arg $1 string 無毒化する外部制御文字列
# @stdout 無毒化した文字列（最大 80 **バイト**・有効 UTF-8）
# @exitcode 0 常に成功
mape_sanitize_signal() {
  local s="$1"
  s=${s//$'\n'/ }; s=${s//$'\r'/ }; s=${s//$'\t'/ }
  s=$(printf '%s' "$s" | LC_ALL=C sed -e 's/[][`<>|\\]//g' -e 's/[[:cntrl:]]//g')
  # 80 バイトで丸める。`${s:0:80}` は bash の substring で、単位が**ロケール依存**（C ではバイト、
  # UTF-8 ロケール=C.UTF-8 等の cron/systemd 既定では文字）。文字単位だと日本語で最大 ~240 バイトになり
  # 「80 バイト」の契約（HEALTH note 列・Execute プロンプトの上限）を破る。`head -c 80` はロケールに依らず
  # 常にバイトで切る。切った末尾に生じうる不完全 UTF-8 断片は iconv -c で落として有効 UTF-8 に保つ。
  s=$(printf '%s' "$s" | head -c 80)
  if command -v iconv >/dev/null 2>&1; then
    s=$(printf '%s' "$s" | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null)
  fi
  printf '%s' "$s"
}

# @description 実行台帳(ledger.jsonl)で指定 item（＝提案テキスト。Execute が record する文字列と厳密一致）の
#   過去の結果を要約する（K→A フィードバック弧を閉じる。ADR-0014 の「生きた核」）。
#   破損行は握り潰す（jq→python3 フォールバック。パーサ無しは無印＝memory 無効でフェイルセーフ）。
#   注意: これはシグナル由来提案には適用しない（呼び出し側 analyze が BACKLOG 取り込み時のみ使う）。
#   シグナルは現状のライブ値であり、過去 green で現在の赤ゲート等を抑制してはならないため。
# @arg $1 string 台帳の item 文字列（提案テキストと厳密一致）
# @stdout `done`（green が1件以上＝実装済み。再提案しない）/ `failing`（green 無し・red が
#   MAPE_CB_SAME_ITEM_FAIL 回以上＝慢性失敗。降格して沈める）/ 空（履歴なし・閾値未満・パーサ無し）
# @exitcode 0 常に成功（判定不能でも呼び出し元を止めない）
mape_ledger_status() {
  local text="$1" ledger="$MAPE_STATE_DIR/ledger.jsonl" green=0 red=0
  [ -f "$ledger" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    local line r
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      r=$(printf '%s\n' "$line" | jq -r --arg it "$text" 'select(.item==$it) | .result' 2>/dev/null) || continue
      case "$r" in green) green=$((green+1));; red) red=$((red+1));; esac
    done < "$ledger"
  elif command -v python3 >/dev/null 2>&1; then
    local out
    out=$(python3 - "$ledger" "$text" <<'PY' 2>/dev/null
import json,sys
path,it=sys.argv[1],sys.argv[2]; g=r=0
# errors="replace" で不正 UTF-8 を許容。非オブジェクト行は isinstance で弾く（.get で落ちると
# その行以降を取りこぼし、out が空→"0 0" になって全 item の memory が無効化される）。
for ln in open(path,encoding="utf-8",errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: o=json.loads(ln)
    except Exception: continue
    if not isinstance(o,dict): continue
    if o.get("item")==it:
        if o.get("result")=="green": g+=1
        elif o.get("result")=="red": r+=1
print(g,r)
PY
) || out="0 0"
    green=${out%% *}; red=${out##* }; green=${green:-0}; red=${red:-0}
  else
    return 0   # JSON パーサ無し → memory 無効（従来どおり。フェイルセーフ）
  fi
  if [ "$green" -ge 1 ] 2>/dev/null; then printf 'done'; return 0; fi
  if [ "$red" -ge "$MAPE_CB_SAME_ITEM_FAIL" ] 2>/dev/null; then printf 'failing'; return 0; fi
  return 0
}

# @description 恒常性（homeostasis）: POLICY「### 健全性バンド（setpoints）」fence 内の行（`metric warn crit`）を
#   出力する。人間がここを編集すれば analyze の反応閾値を（コードでなく）POLICY で調律できる（ADR-0004/0014）。
# @noargs
# @stdout `metric warn crit` の行（1行1指標）。POLICY 不在／見出し不在なら無出力
# @exitcode 0 常に成功
# @see mape_band_status
mape_setpoints() {
  [ -f "$MAPE_POLICY" ] || return 0
  awk '
    /^### 健全性バンド/ { found=1; infence=0; next }
    found && /^```/     { if (infence) exit; else { infence=1; next } }
    found && infence    { print }
  ' "$MAPE_POLICY"
}

# @description 指標 value がバンドのどこか（ok|warn|crit）を返す。POLICY の setpoint を優先し、無ければ
#   baked-in 既定（従来 analyze のしきい値を包含）。direction は lower（小さいほど良い）前提。
#   非数値（"-" 等）や warn/crit が壊れている場合は ok（判定せず・フェイルセーフ）。
#   ここでの ok は「提案を1件出さない」だけで安全境界には触れないため、fail-open ではなく
#   ノイズを出さない方向のフェイルセーフとして正しい。
# @arg $1 string 指標名（gate_s|todo|claude_md|max_skill …）
# @arg $2 string 指標の現在値（非数値なら判定せず ok）
# @stdout ok|warn|crit
# @exitcode 0 常に成功
mape_band_status() {
  local m="$1" v="$2" warn crit sp
  case "$v" in ''|*[!0-9]*) echo ok; return 0 ;; esac
  sp=$(mape_setpoints | awk -v m="$m" '$1==m { print $2" "$3; exit }')
  if [ -n "${sp// /}" ]; then warn=${sp%% *}; crit=${sp##* }
  else case "$m" in
    gate_s)    warn=15;  crit=30  ;;
    todo)      warn=1;   crit=10  ;;
    claude_md) warn=190; crit=200 ;;
    max_skill) warn=450; crit=500 ;;
    *) echo ok; return 0 ;;
  esac; fi
  # warn/crit を **個別に** 検証する。連結（"$warn$crit"）だと片方欠落（例 setpoint "todo 5" で
  # crit=""）が "5"+"" = "5" となり全数字チェックを通過し、crit 判定が空文字比較で落ちて crit 値を
  # warn に誤降格する。片方でも非数値/空なら契約どおり ok（判定せず・フェイルセーフ）へ倒す。
  case "$warn" in ''|*[!0-9]*) echo ok; return 0 ;; esac
  case "$crit" in ''|*[!0-9]*) echo ok; return 0 ;; esac
  if   [ "$v" -ge "$crit" ] 2>/dev/null; then echo crit
  elif [ "$v" -ge "$warn" ] 2>/dev/null; then echo warn
  else echo ok; fi
}

# @description DNA 完全性（ADR-0014）: ライブ知識ファイルの機械可読な不変条件を検査する（fail-closed）。
#   壊れていたら壊れたファイルのパスを stderr に名指しして非0で返す。check.sh（単一ゲート・ADR-0004）が
#   実データに対して呼ぶ。テストは MAPE_HEALTH/MAPE_POLICY/MAPE_BACKLOG/MAPE_STATE_DIR を差し替えて個別に壊す。
#   各ファイルは「在れば整合、無ければ許容」（最小構成/CI での不在で壊れないため）。tier 判定・書き換えはしない。
#   JSON パーサ非在は ledger 検査スキップ＝フェイルセーフ（record/status と対称）。
#
#   検査する不変条件:
#    - HEALTH: 推移表ヘッダ(ts(UTC))が在り、各データ行の列数がヘッダと一致する
#    - POLICY: consult/approve/auto 見出しが揃い、却下ログ pattern が有効な正規表現である
#    - BACKLOG: analyze の永続化挿入点「## アーカイブ」アンカーが在る
#    - ledger.jsonl: 非空行がすべて有効 JSON かつ ts/item/result を持つ（空白のみの行は許容）
# @noargs
# @stderr `knowledge-integrity: <内容>: <パス>`（壊れた項目ごとに1行）
# @exitcode 0 すべて整合（またはファイル不在）
# @exitcode 1 いずれかの不変条件が壊れている（safe-state はこれを unsafe に畳む）
# @see mape/safe-state.sh
mape_verify_knowledge() {
  local rc=0 f
  # HEALTH: 推移表ヘッダ(ts(UTC))が在り、各データ行の列数(awk NF)がヘッダと一致する
  f="$MAPE_HEALTH"
  if [ -f "$f" ]; then
    local hnf
    hnf=$(awk -F'|' '/ts\(UTC\)/ { print NF; exit }' "$f")
    if [ -z "$hnf" ]; then
      printf 'knowledge-integrity: HEALTH 推移表ヘッダ(ts(UTC))が無い: %s\n' "$f" >&2; rc=1
    elif ! awk -F'|' -v want="$hnf" '/^\| [0-9][0-9][0-9][0-9]-/ { if (NF!=want) bad=1 } END { exit bad?1:0 }' "$f"; then
      printf 'knowledge-integrity: HEALTH データ行の列数がヘッダと不一致: %s\n' "$f" >&2; rc=1
    fi
  fi
  # POLICY: consult/approve/auto 見出しが揃い、却下ログ pattern が有効な正規表現である
  f="$MAPE_POLICY"
  if [ -f "$f" ]; then
    local h pat gs
    for h in '### consult' '### approve' '### auto'; do
      grep -qF -- "$h" "$f" || { printf 'knowledge-integrity: POLICY 見出し欠落 (%s): %s\n' "$h" "$f" >&2; rc=1; }
    done
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      printf 'x\n' | grep -iE -- "$pat" >/dev/null 2>&1; gs=$?
      if [ "$gs" -ge 2 ]; then
        printf 'knowledge-integrity: POLICY 却下ログの不正な正規表現 (%s): %s\n' "$pat" "$f" >&2; rc=1
      fi
    done < <(grep -E '^- pattern:' "$f" 2>/dev/null \
              | sed -E 's/^- pattern:[[:space:]]*//' | sed 's/[[:space:]]*—.*$//' | sed -E 's/[[:space:]]+$//')
  fi
  # BACKLOG: アーカイブ・アンカー（analyze の永続化挿入点）が在る
  f="$MAPE_BACKLOG"
  if [ -f "$f" ]; then
    grep -qF '## アーカイブ' "$f" || { printf 'knowledge-integrity: BACKLOG に「## アーカイブ」アンカーが無い: %s\n' "$f" >&2; rc=1; }
  fi
  # ledger.jsonl: 非空行はすべて有効 JSON かつ ts/item/result を持つ（空行は許容）。jq→python3 対称。
  f="$MAPE_STATE_DIR/ledger.jsonl"
  if [ -f "$f" ]; then
    if command -v jq >/dev/null 2>&1; then
      local line
      while IFS= read -r line; do
        # 空行だけでなく **空白のみの行** も許容する（python3 経路の ln.strip() と揃える。
        # さもないと partial append 等で入った空白行を jq 経路だけ不正扱いし、同じ台帳でも
        # インストール済みパーサ次第でこの DNA ゲートの verdict が緑↔赤に振れる非決定論になる）。
        case "$line" in *[![:space:]]*) ;; *) continue ;; esac
        if ! printf '%s\n' "$line" | jq -e 'has("ts") and has("item") and has("result")' >/dev/null 2>&1; then
          printf 'knowledge-integrity: ledger の不正な行/必須キー欠落(ts,item,result): %s\n' "$f" >&2; rc=1; break
        fi
      done < "$f"
    elif command -v python3 >/dev/null 2>&1; then
      if ! python3 - "$f" <<'PY' 2>/dev/null
import json,sys
ok=True
# errors="replace": 不正 UTF-8 バイトで読み取り自体をクラッシュさせない。これが無いと python3 経路
# だけ UnicodeDecodeError で rc=1（DNA ゲート RED）になり、jq 経路（byte を許容）と verdict が食い違う
# ＝インストール済みパーサ次第でゲートの合否が変わる非決定論。他パーサと同じく errors="replace" で揃える。
for ln in open(sys.argv[1],encoding="utf-8",errors="replace"):
    ln=ln.strip()
    if not ln: continue
    try: o=json.loads(ln)
    except Exception: ok=False; break
    if not (isinstance(o,dict) and all(k in o for k in ("ts","item","result"))): ok=False; break
sys.exit(0 if ok else 1)
PY
      then
        printf 'knowledge-integrity: ledger の不正な行/必須キー欠落(ts,item,result): %s\n' "$f" >&2; rc=1
      fi
    fi
  fi
  return "$rc"
}

# @description UTC タイムスタンプ 'YYYY-MM-DDTHH:MMZ'（mape_now と同形式）を epoch 秒へ。壊れた入力は空文字（フェイルセーフ）。
#   date -u -d は BSD 非対応のため使わず、days_from_civil（純整数演算）で決定論的に算出する（1970 以降専用）。
#   心拍/休眠自己検知（ADR-0014）が「最終 HEALTH 追記からの経過」を移植的に測るための土台。
#   呼び出し側は空文字を必ず「判定不能」として扱うこと（0 と混同すると 1970 起点の巨大な経過時間になる）。
# @arg $1 string UTC タイムスタンプ（'YYYY-MM-DDTHH:MMZ' 以外・範囲外は空文字を返す）
# @stdout epoch 秒（整数）。形式不正・範囲外なら空文字
# @exitcode 0 常に成功（判定不能は stdout の空文字で表す）
# @see mape_now
mape_epoch_utc() {
  local ts="$1" y mo d h mi yy era yoe doy doe days
  case "$ts" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]Z) ;;
    *) return 0 ;;
  esac
  y=$((10#${ts:0:4})); mo=$((10#${ts:5:2})); d=$((10#${ts:8:2}))
  h=$((10#${ts:11:2})); mi=$((10#${ts:14:2}))
  { [ "$mo" -ge 1 ] && [ "$mo" -le 12 ] && [ "$d" -ge 1 ] && [ "$d" -le 31 ] \
    && [ "$h" -le 23 ] && [ "$mi" -le 59 ]; } || return 0
  yy=$(( y - (mo <= 2 ? 1 : 0) ))
  era=$(( (yy >= 0 ? yy : yy-399) / 400 ))
  yoe=$(( yy - era*400 ))
  doy=$(( (153*(mo + (mo > 2 ? -3 : 9)) + 2)/5 + d-1 ))
  doe=$(( yoe*365 + yoe/4 - yoe/100 + doy ))
  days=$(( era*146097 + doe - 719468 ))
  printf '%s' "$(( days*86400 + h*3600 + mi*60 ))"
}

# @section 項目隔離（quarantine）
# @description 項目隔離（quarantine。自己修復。ADR-0015）: 毒項目1件で全 Execute を止めず、その項目だけを
#   BACKLOG.md「## ブロック中」へ隔離してループの生存を保つ。以下は隔離リストの読み書き。
#   隔離は同一項目ブレーカーだけを黙らせるもので、GLOBAL 暴走停止（末尾連続 red・直近 window red）は
#   隔離でも cooldown でも決して解除されない。

# @description 隔離リスト（## ブロック中）の各エントリ本文を出力する（先頭 '- ' を除く。次の見出し/EOF で区切る）。
# @noargs
# @stdout 隔離エントリ本文（1行1件。形式は "<item> — reason (ts)"）。BACKLOG 不在なら無出力
# @exitcode 0 常に成功
mape_quarantined_items() {
  [ -f "$MAPE_BACKLOG" ] || return 0
  awk '
    /^## ブロック中/ { inb=1; next }
    /^## / && inb    { inb=0 }
    inb && /^- /     { sub(/^- /,""); print }
  ' "$MAPE_BACKLOG"
}

# @description 提案テキストが隔離済みか。エントリは "<item> — reason (ts)"（quarantine_add が必ず ` — ` で
#   区切る）なので、item を **境界一致** で判定する: 行が `<text> — …` で始まる、または `<text>` に等しい。
#   旧実装の grep -qF は部分一致で、item の途中や reason 語に一致する別項目まで「隔離済み」と誤判定し、
#   その別項目の同一項目トリップ（GLOBAL 保護の一部）を黙らせていた（過剰抑止）。case のクォート部は
#   リテラル扱いなので text に glob メタ文字があっても安全。
# @arg $1 string 判定する提案テキスト（空なら常に非隔離）
# @exitcode 0 隔離済み（analyze は再提案せず、同一項目ブレーカーからも除外される）
# @exitcode 1 未隔離／空文字／BACKLOG 不在
mape_is_quarantined() {
  local text="$1" line
  [ -n "$text" ] || return 1
  while IFS= read -r line; do
    case "$line" in
      "$text — "*) return 0 ;;   # <item> — reason (ts)（item が text と厳密一致する境界）
      "$text")     return 0 ;;   # 念のための完全一致（reason 無しエントリ）
    esac
  done < <(mape_quarantined_items)
  return 1
}

# @description 項目を「## ブロック中」へ追記（冪等・無毒化・ファイル末尾にセクション生成）。circuit-breaker から呼ぶ。
#   **knowledge/BACKLOG.md を書き換える数少ない関数**（他の mape_* は read-only）。
#   reason は外部由来なので mape_sanitize_signal を必ず通してから書く。
# @arg $1 string 隔離する item（提案テキスト。必須）
# @arg $2 string 隔離理由（省略時は「隔離」。無毒化してから書き込む）
# @stderr `[mape] 隔離: <item>` または `[mape] 既に隔離済み: <item>`
# @exitcode 0 隔離した／既に隔離済み／BACKLOG 不在でスキップ
# @exitcode 1 item が空
mape_quarantine_add() {
  local item="$1" reason="${2:-}" ts entry tmp
  [ -n "$item" ] || return 1
  [ -f "$MAPE_BACKLOG" ] || { mape_log "BACKLOG 不在。隔離をスキップ"; return 0; }
  if mape_is_quarantined "$item"; then mape_log "既に隔離済み: $item"; return 0; fi
  reason=$(mape_sanitize_signal "$reason"); ts=$(mape_now)
  entry="- ${item} — ${reason:-隔離} (${ts})"
  if grep -qxF '## ブロック中' "$MAPE_BACKLOG" 2>/dev/null; then
    tmp=$(mktemp)
    # ENVIRON で渡す（awk -v は \n/\\ を解釈するため item の任意文字に不安全）
    QENTRY="$entry" awk '
      /^## ブロック中/ && !ins { print; print ENVIRON["QENTRY"]; ins=1; next }
      { print }
    ' "$MAPE_BACKLOG" > "$tmp" && mv "$tmp" "$MAPE_BACKLOG"
  else
    { printf '\n## ブロック中\n\n'
      printf '<!-- circuit-breaker.sh quarantine が追記。analyze はここの項目を再提案せず、同一項目ブレーカーからも除外する（自己修復。ADR-0015）。 -->\n\n'
      printf '%s\n' "$entry"; } >> "$MAPE_BACKLOG"
  fi
  mape_log "隔離: $item（→ knowledge/BACKLOG.md ## ブロック中）"
}

# @description 隔離クリアの最小 dwell が経過したか（MAPE_CB_COOLDOWN_H 時間）。tripped_at 不明/壊れは「経過」扱い
#   （安全＝クリア許可）。cooldown は回復を遅らせるだけで、暴走停止を緩めることは決してない。
# @noargs
# @exitcode 0 経過済み（cooldown 無効 0 / tripped_at 不在 / ts 破損 を含む）
# @exitcode 1 未経過（隔離による同一項目トリップのクリアをまだ許さない）
# @see mape_epoch_utc
mape_cooldown_elapsed() {
  local f="$MAPE_STATE_DIR/breaker.tripped_at" te ne cool
  cool="${MAPE_CB_COOLDOWN_H:-0}"
  [ "$cool" -gt 0 ] 2>/dev/null || return 0
  [ -f "$f" ] || return 0
  te=$(mape_epoch_utc "$(cat "$f" 2>/dev/null)"); ne=$(date -u +%s 2>/dev/null)
  [ -n "$te" ] && [ -n "$ne" ] || return 0
  [ "$(( ne - te ))" -ge "$(( cool * 3600 ))" ] 2>/dev/null
}
