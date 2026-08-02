#!/usr/bin/env bash
# @file scripts/check-traceability.sh
# @brief 要件トレーサビリティ（要件 ID ⇄ `Verifies:` 参照）の機械検証。
# @description
#   要件トレーサビリティの機械検証（ADR-0006 / docs/process/traceability.md）。
#   scripts/check.sh から呼ばれる品質ゲート。
#
#   検査:
#     1) docs/requirements/ の全 REQ-*/NFR-* が、リポジトリ内で `Verifies: <ID>` として参照されている
#     2) 各要件ドキュメントに受入基準セクションがある
#     3) 発行 ID が規約の形式に沿う
#   要件ドキュメントが無い土台の初期状態では「対象なし＝合格」を返す。
# @exitcode 0 合格（未被覆・形式違反・受入基準欠落が無い。対象なしも合格）
# @exitcode 1 未被覆の要件・ID 形式違反・受入基準欠落のいずれかを検知
# @stdout 判定結果の要約
# @stderr 違反ごとの "NG(traceability): …"
set -u

cd "$(dirname "$0")/.." || exit 1

REQ_DIR="docs/requirements"
fail=0
# @description 違反を報告し fail フラグを立てる（1件目で打ち切らず全件を報告するため）。
# @internal
# @arg $@ string 違反の説明
# @set fail int 1
# @stderr "NG(traceability): 説明"
ng() { echo "NG(traceability): $*" >&2; fail=1; }

# 要件ディレクトリが無ければ何もしない（スタック導入・要件定義前）
if [ ! -d "$REQ_DIR" ]; then
  echo "traceability: 対象なし（$REQ_DIR 未作成）＝合格"
  exit 0
fi

# 要件ファイル一覧（-L: シンボリックリンクも辿る。要件を symlink で置いても見落とさない）
req_files=()
while IFS= read -r f; do req_files+=("$f"); done < <(find -L "$REQ_DIR" -type f -name '*.md' 2>/dev/null)
if [ "${#req_files[@]}" -eq 0 ]; then
  echo "traceability: 要件ファイルなし＝合格"
  exit 0
fi

# 発行済み ID を収集する。散文中の言及を「幻の要件」にしないため、ID が
# **宣言行**（見出し `#…` または表の行 `|…`）に現れるものだけを発行済みと見なす
# （template: 機能要件は `### REQ-…:` 見出し、NFR は表の行）。参照行（`Verifies:`）は除く。
# 宣言行から ID 候補を緩く抽出する（4桁や小文字など不正形式も捕捉して後で弾くため、
# 抽出は緩いパターン、検証は厳格パターンで行う）。`Verifies:` 同居時は参照部分だけ削る。
# フェンス（``` … ``` または ~~~ … ~~~）で囲まれたコードブロックを除去する。ブロック内の
# 説明用見出し（例 `### REQ-EXAMPLE-999:`）を実在要件と誤認しないため（false positive 防止）。
# 注意点:
#  - FNR==1 でファイル境界ごとにフラグを戻す（複数ファイル一括時のフェンス漏れ防止）。
#  - フェンス種別（``` / ~~~）を記録し、開いた種別と同種のマーカーでのみ閉じる。無条件トグルだと
#    ``` ブロック内の ~~~ 行（またはその逆）で早期クローズし、以降の例示見出しが漏出する。
# @description コードフェンス（``` … ``` / ~~~ … ~~~）で囲まれた行を落として残りを出力する。
#   フェンス内の説明用見出し（例 `### REQ-EXAMPLE-999:`）を実在要件と誤認しないため（false positive 防止）。
#   FNR==1 でファイル境界ごとにフラグを戻し、フェンス種別を記録して同種のマーカーでのみ閉じる
#   （上のコメント参照。無条件トグルだと異種マーカーで早期クローズして例示見出しが漏出する）。
# @internal
# @arg $@ path 走査する要件ファイル（複数可）
# @stdout フェンス内を除いた各行
strip_fences() {
  awk 'FNR==1 { f=0; fence="" }
       {
         if (match($0, /^[[:space:]]*(```|~~~)/)) {
           m = substr($0, RSTART, RLENGTH); gsub(/[[:space:]]/, "", m); m = substr(m, 1, 3)
           if (f == 0)            { f = 1; fence = m; next }   # オープン
           else if (m == fence)   { f = 0; fence = "";  next } # 同種でクローズ
           else                   { next }                     # フェンス内の別種マーカーは中身扱い
         }
         if (!f) print
       }' "$@"
}

# 抽出側の grep は必ず -a（--text）を付ける。要件ファイルに NUL バイト等が1つでも混ざると
# GNU grep は入力をバイナリ扱いして一致行を出力しなくなり、宣言済み要件が丸ごと消えて
# 「宣言された要件 ID なし＝合格」に倒れる（未被覆要件を見逃す fail-open）。-a で必ず読む。
ids=$(strip_fences "${req_files[@]}" 2>/dev/null \
  | grep -aE '^[[:space:]]*(#{1,6}|\|).*(REQ|NFR)-[A-Za-z0-9]+-[A-Za-z0-9]+' \
  | sed 's/Verifies:.*$//' | grep -aoE '(REQ|NFR)-[A-Za-z0-9]+-[A-Za-z0-9]+' | sort -u)

if [ -z "$ids" ]; then
  echo "traceability: 宣言された要件 ID なし＝合格（要件は見出しまたは表で宣言する）"
  exit 0
fi

# 被覆の収集: `Verifies:` を含む行の ID を集める。ただし要件ツリー（$REQ_DIR）自身は
# 除外し、要件が自分自身を「検証」する自己参照の抜け穴を塞ぐ（テストは要件ツリー外に置く）。
# DES-<3桁>（中間語なし）も参照 ID として認識する。
# 要件ツリーの除外は「パス接頭辞」で行う。--exclude-dir=<basename> は GNU grep では
# 深さを問わず同名ディレクトリすべてに一致するため、`src/requirements/` 等ツリー外の
# `requirements` ディレクトリの被覆まで黙って落とし、要件を未被覆と誤判定して gate が
# 偽赤になる（/stack-init 後に pip 系 requirements/ が現れると発火）。find の -prune で
# .git と $REQ_DIR を「正確なパス」で刈り、grep -h でファイル名を一切出力に混ぜない
# （grep -rH + sed でパス接頭辞を剥がす方式は、パスにコロンや REQ 形トークンを含む
# ファイル名が幻の被覆として漏れる。ID 抽出にファイル名を触れさせないのが堅牢）。
# $REQ_DIR 直下は刈るので自己参照の抜け穴は維持される。-exec {} + は対象0件なら grep を
# 起動しない（空入力での grep stdin ハングも回避）。
# ID の両端を \b で境界化する。右端の境界が無いと 4桁以上の ID（例 REQ-FIX-0012）が
# 先頭3桁（REQ-FIX-001）に切り詰められ、別要件の被覆として誤カウントされる。左端の境界が
# 無いと `XREQ-FIX-001` のような別トークンの部分一致が被覆に化ける（どちらも false coverage）。
# 被覆側は意図的に -a を付けない（バイナリ中の 'Verifies:' 文字列を被覆に数えない＝fail-closed。
# 抽出側だけ -a を付ける非対称は、どちらも「未被覆を見逃さない」向きに倒すための設計）。
verifies=$(find . -name .git -prune -o -path "./$REQ_DIR/*" -prune -o -type f \
    -exec grep -hE 'Verifies:' {} + 2>/dev/null \
  | grep -oE '\b(REQ|NFR)-[A-Z]+-[0-9]{3}\b|\bDES-[0-9]{3}\b' | sort -u)

# 1) & 3) 各 ID の形式と被覆（Verifies: 参照の存在）を検査
while IFS= read -r id; do
  [ -z "$id" ] && continue
  # 形式チェック（不正なら被覆チェックはせず次へ）
  if ! echo "$id" | grep -Eq '^(REQ|NFR)-[A-Z]+-[0-9]{3}$'; then
    ng "ID 形式が不正: $id（REQ-<領域大文字>-<3桁> / NFR-<分類大文字>-<3桁> にする）"
    continue
  fi
  if ! printf '%s\n' "$verifies" | grep -qx "$id"; then
    ng "要件 $id を検証するテストがない（要件ツリー外のどこかに 'Verifies: $id' が必要）"
  fi
done <<< "$ids"

# 2) 要件を宣言しているファイルだけ、受入基準セクションの有無を検査する
#    （README/index など要件宣言のないファイルは対象外）
for f in "${req_files[@]}"; do
  # 宣言判定もフェンス内の例を除外する（コードブロック内の見出しで誤発火しない）
  strip_fences "$f" | grep -qE '^[[:space:]]*(#{1,6}|\|).*(REQ|NFR)-[A-Z]+-[0-9]{3}' || continue
  if ! grep -qiE '受入基準|acceptance criteria' "$f"; then
    ng "$f に受入基準セクションがない"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "traceability: 失敗" >&2
  exit 1
fi
echo "traceability: 合格（要件 $(printf '%s\n' "$ids" | grep -c . ) 件すべてに対応テストあり）"
