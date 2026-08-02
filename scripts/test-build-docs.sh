#!/usr/bin/env bash
# @file scripts/test-build-docs.sh
# @brief build-docs.sh（reference.html 生成器）の動作テスト
# @description
#   mktemp -d の合成フィクスチャで正常系・異常系を検証する。実ツリーは一切書き換えない。
#   重点は「黙って合格しない」こと: 乖離・ツール欠落・引数の誤記で必ず非ゼロに倒れること。
#   加えて「読んで分かる」ための表示契約（役割グループ・1行説明・未分類の救済・検索 UI・
#   日本語ラベル・非表示件数の明示）を固定する。
set -u

cd "$(dirname "$0")/.." || exit 1

fail=0
# @internal
pass() { echo "PASS: $1"; }
# @internal
bad()  { echo "FAIL: $1" >&2; fail=1; }
# @internal
ok()   { if [ "$1" -eq 0 ]; then pass "$2"; else bad "$2（exit=$1）"; fi; }
# @internal
ng()   { if [ "$1" -ne 0 ]; then pass "$2"; else bad "$2（exit=0 のまま素通り）"; fi; }
# @internal
eq()   { if [ "$1" = "$2" ]; then pass "$3"; else bad "$3（期待 '$2' / 実際 '$1'）"; fi; }
# @internal
has()  { if grep -q -- "$2" "$1"; then pass "$3"; else bad "$3"; fi; }
# @internal
hasnt(){ if grep -q -- "$2" "$1"; then bad "$3"; else pass "$3"; fi; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# 合成フィクスチャの中身は「@! を落として書き出す」形で埋め込む。
# 素の `# @description` を直接書くと、この*テストスクリプト自身*が shdoc に
# 「サンプル関数を公開している」と読まれ、reference.html が実態とズレる。
# @internal
mkfile() { # $1=出力先。標準入力の各行から先頭の @! を落とす
  sed 's/^@!//' > "$1"
}

# 指定コマンドだけを持つ bin ディレクトリを作る（ツール欠落の敵対テスト。test-guard-protected.sh と同じ手）
# @internal
mkbin() { # $@=必要コマンド → 生成した bin ディレクトリを返す
  local d p b
  d=$(mktemp -d)
  for b in "$@"; do
    p=$(command -v "$b" 2>/dev/null) && ln -s "$p" "$d/$b"
  done
  printf '%s' "$d"
}

# 索引のうち指定グループの節だけを取り出す（未分類の救済・グループ分けの検証に使う）
# @internal
grpsec() { # $1=HTML $2=グループ節の id
  awk -v id="$2" 'index($0, "id=\"" id "\"") { on = 1 } on { print } on && /<\/section>/ { exit }' "$1"
}

# 指定文字列が最初に現れる行番号（グループの並び順の検証に使う）
# @internal
lineof() { # $1=HTML $2=検索文字列
  grep -n -- "$2" "$1" | head -1 | sed 's/:.*//'
}

# 指定モジュールの結論段落（p.sum.answer）の中身を取り出す（ピラミッド原則の検証に使う）
# @internal
modanswer() { # $1=HTML $2=モジュールの id
  awk -v id="$2" '
    index($0, "<section class=\"mod\" id=\"" id "\">") { on = 1; next }
    on && index($0, "<p class=\"sum answer\">") {
      grab = 1
      s = $0
      sub(/^.*<p class="sum answer">/, "", s)
      if (s ~ /<\/p>$/) { sub(/<\/p>$/, "", s); print s; exit }
      if (s != "") print s
      next
    }
    grab && /<\/p>/ { exit }
    grab { print }
  ' "$1"
}

# 合成フィクスチャ（実リポジトリの中身に依存させない）。
# scripts/ mape/ .claude/hooks/ の3領域を用意し、注記あり・注記なし・危険文字を混ぜる。
# scripts/sample-a.sh はどのグループ規則にも当てはまらない＝「その他」に落ちる検体でもある。
# @internal
mkfix() { # $1=フィクスチャのルート（絶対パス）
  local d="$1"
  rm -rf "$d"; mkdir -p "$d/scripts" "$d/mape" "$d/.claude/hooks" "$d/tools/shdoc"
  cp scripts/build-docs.sh "$d/scripts/"
  cp tools/shdoc/shdoc "$d/tools/shdoc/"; chmod +x "$d/tools/shdoc/shdoc"
  # 生成物がピラミッド原則の構成検査（.claude/rules/docs.md）を通ることを固定するために同梱する。
  # scripts/ に置くと文書化対象の glob に載って検体が増えるので tools/ に置く。
  cp scripts/check-docs-structure.sh "$d/tools/"
  # 構成検査は用語集の正本（規約）と自身の語彙の一致も見るので、規約も同梱する。
  mkdir -p "$d/.claude/rules"; cp .claude/rules/docs.md "$d/.claude/rules/"

  mkfile "$d/scripts/sample-a.sh" <<'FIXA'
@!#!/usr/bin/env bash
@!# @file sample-a.sh
@!# @brief サンプルA
@!# @description
@!#   複数行の説明。`インラインコード` と **強調** と _斜体_ を含む。
@!#   箇条書き:
@!#   - 項目1
@!#   - 項目2

@!# @description 挨拶する
@!# @arg $1 string 名前
@!# @arg $2 int 回数
@!# @exitcode 0 成功
@!# @exitcode 1 失敗
@!# @stdout 挨拶文
@!# @example
@!#   greet foo 3
greet() { echo "$1"; }

@!# @description 注記のある2つめの関数
@!# @noargs
farewell() { :; }

@!# @description 1文目のみ索引に出る。2文目は索引に出ない。
@!# @noargs
two_sentences() { :; }

@!# @description 括弧（中に。を含む）の外で切る。ここから2文目。
@!# @noargs
paren_period() { :; }

@!# @description 行またぎの説明でも
@!#   1文として拾える。ここから2文目。
@!# @noargs
wrapped_desc() { :; }

@!# @internal
hidden_fn() { :; }
FIXA

  # 結論（p.answer）は1文まで。2文目以降は続く段落に回ることを確かめる検体
  mkfile "$d/scripts/sample-d.sh" <<'FIXD'
@!#!/usr/bin/env bash
@!# @file sample-d.sh
@!# @brief 結論は先頭1文。2文目以降は続く段落に回す。
@!# @description
@!#   本文の説明。
FIXD

  # 括弧の中に句点がある @brief（「。」が2つ残ると結論1文の規約に反するため括弧の手前で切る）
  mkfile "$d/scripts/sample-e.sh" <<'FIXE'
@!#!/usr/bin/env bash
@!# @file sample-e.sh
@!# @brief 括弧つきの結論（中に。を含む）。ここから2文目。
@!# @description
@!#   本文の説明。
FIXE

  # @brief が無いモジュール（結論段落を欠いたまま出さないための保険を確かめる検体）
  mkfile "$d/scripts/sample-f.sh" <<'FIXF'
@!#!/usr/bin/env bash
@!# @file sample-f.sh
@!# @description
@!#   - 箇条書きで始まる説明
@!#   - 2項目め
FIXF

  mkfile "$d/mape/sample-b.sh" <<'FIXB'
@!#!/usr/bin/env bash
@!# @file sample-b.sh
@!# @brief 危険文字 & < > " を含むサンプル
@!# @description
@!#   HTML を壊しうる文字: & < > " と <script>alert("x")</script> と <b>bold</b>。

@!# @description a < b && c > d を判定する "引用符つき"
@!# @arg $1 string <値> & "他"
@!# @exitcode 0 真
@!# @exitcode 1 偽
cmp_lt() { :; }
FIXB

  mkfile "$d/.claude/hooks/sample-c.sh" <<'FIXC'
@!#!/usr/bin/env bash
@!# 注記の無いフック。先頭のコメントブロックが説明として使われる。
@!# 2行目の説明。
set -u
echo hook
FIXC
}

bd()  { ( cd "$1" && shift && bash scripts/build-docs.sh "$@" >/dev/null 2>&1 ); }
bdo() { ( cd "$1" && shift && bash scripts/build-docs.sh "$@" 2>&1 ); }

F="$work/fx"; mkfix "$F"
H="$F/docs/reference.html"

# --- 正常系 -----------------------------------------------------------------
bd "$F"; ok $? "合成フィクスチャから生成できる"
[ -f "$H" ] && pass "reference.html ができる" || bad "reference.html が無い"
bd "$F" --check; ok $? "生成直後は --check 合格"
eq "$(bdo "$F" --check | tail -1 | cut -c1-9)" "docs-sync" "--check の成功メッセージが docs-sync 様式"

# --- 目次と内容 -------------------------------------------------------------
has "$H" 'href="#mod-scripts-sample-a-sh"'      "目次に scripts/sample-a.sh が載る"
has "$H" 'href="#mod-mape-sample-b-sh"'         "目次に mape/sample-b.sh が載る"
has "$H" 'href="#mod-claude-hooks-sample-c-sh"' "目次に .claude/hooks/sample-c.sh が載る"
has "$H" 'href="#mod-scripts-build-docs-sh"'    "目次に scripts/build-docs.sh 自身が載る"
has "$H" 'id="mod-scripts-sample-a-sh-greet"'   "関数 greet の見出しがある"
has "$H" 'id="mod-mape-sample-b-sh-cmp_lt"'     "関数 cmp_lt の見出しがある"
hasnt "$H" 'hidden_fn'                          "@internal の関数は出さない"
has "$H" '<strong>\$1</strong> (string): 名前'  "引数が型つきで載る"
has "$H" '<strong>0</strong>: 成功'             "終了コードが載る"
has "$H" '<pre><code class="language-bash">'    "@example がコードブロックになる"
has "$H" '<strong>強調</strong>'                "**強調** が strong になる"
has "$H" '<em>斜体</em>'                        "_斜体_ が em になる"
has "$H" '<code>インラインコード</code>'         "インラインコードが code になる"
has "$H" '<li>項目1</li>'                        "箇条書きが li になる"
has "$H" '注記の無いフック'                       "注記なしでも先頭コメントから説明を出す"
has "$H" 'shdoc 注記が未整備'                     "注記なしモジュールにはその旨を明示する"
# id の重複（引数・終了コード等が関数ごとに繰り返される）は HTML として不正
eq "$(grep -o 'id="[^"]*"' "$H" | sort | uniq -d | wc -l)" "0" "id が重複しない"

# --- 索引の1行説明（名前の羅列にしない。Round 11 #46） ----------------------
has "$H" '<li class="fn-item">.*<code>greet</code>.*<span class="d">挨拶する' \
  "索引の関数リンクに1行説明が並ぶ"
has "$H" '<li class="fn-item">.*two_sentences.*1文目のみ索引に出る。</span>' \
  "索引の説明は先頭1文だけ"
hasnt "$H" '<li class="fn-item">.*two_sentences.*2文目は索引に出ない' \
  "索引の説明に2文目を混ぜない"
has "$H" '<li class="fn-item">.*paren_period.*括弧（中に。を含む）の外で切る。</span>' \
  "括弧内の句点では切らない"
has "$H" '<li class="fn-item">.*wrapped_desc.*行またぎの説明でも1文として拾える。</span>' \
  "行をまたぐ1文も索引に拾える"
has "$H" '<div class="mod-line">.*sample-a.sh</a> <span class="d">サンプルA' \
  "索引のモジュール行に @brief の1行説明が並ぶ"
has "$H" '<summary>関数 [0-9]* 件</summary>' "索引に関数の件数を出す"

# --- 役割グループ（アルファベット順の羅列にしない） --------------------------
has "$H" 'id="grp-hook"'  "索引に「フック」グループがある"
has "$H" 'id="grp-mape"'  "索引に「MAPE-K」グループがある"
has "$H" 'id="grp-tool"'  "索引に「ツール」グループがある"
has "$H" 'id="g-hook"'    "本文にもグループ見出しがある"
grpsec "$H" grp-hook | grep -q 'sample-c.sh' \
  && pass ".claude/hooks/* はフックグループに入る" || bad ".claude/hooks/* がフックグループに入らない"
grpsec "$H" grp-mape | grep -q 'sample-b.sh' \
  && pass "mape/* は MAPE-K グループに入る" || bad "mape/* が MAPE-K グループに入らない"
grpsec "$H" grp-tool | grep -q 'build-docs.sh' \
  && pass "build-*.sh はツールグループに入る" || bad "build-*.sh がツールグループに入らない"
# 未分類（どの規則にも当てはまらない scripts/sample-a.sh）は黙って落とさず「その他」に出す
has "$H" 'id="grp-other"' "未分類グループ（その他）を出す"
grpsec "$H" grp-other | grep -q 'sample-a.sh' \
  && pass "未分類のモジュールは「その他」に救済される" || bad "未分類のモジュールが索引から消えた"
# 本文のグループ順は定義順（ツール → その他）で決まる
[ "$(lineof "$H" 'id="g-tool"')" -lt "$(lineof "$H" 'id="g-other"')" ] \
  && pass "本文のグループ順が定義順になる" || bad "本文のグループ順が定義順でない"
# 全モジュールが索引に出ている（グループ分けで1件も落ちない）
eq "$(grep -c '<li class="mod-item">' "$H")" "7" "索引のモジュール件数が対象件数と一致する"

# --- 検索 UI（依存ゼロ・JS 無効でも全件見える） ------------------------------
has "$H" 'id="q" type="search"'      "索引の検索ボックスがある"
has "$H" 'id="qn"'                   "一致件数の表示領域がある"
has "$H" 'q.addEventListener'        "インクリメンタル絞り込みの JS がある"
hasnt "$H" '<script src'             "外部 JS を読み込まない"
hasnt "$H" '<link rel="stylesheet"'  "外部 CSS を読み込まない"
hasnt "$H" '@import'                 "CSS の外部取り込みが無い"
hasnt "$H" 'cdn\.'                   "CDN を参照しない"
# JS 無効でも索引は全件が DOM に出ている（隠すのは検索欄だけ）
eq "$(grep -c 'class="fn-item"' "$H")" "$(grep -c '<li class="fn-item">' "$H")" "索引の関数行は静的 HTML に全件ある"
has "$H" '<div class="find" id="find" hidden>' "検索欄は JS が有効なときだけ現れる"

# --- 関数カード（日本語ラベル・定義元リンク・内部ヘルパーの件数明示） --------
has "$H"  '>引数<'                 "引数の節が日本語ラベル"
has "$H"  '>終了コード<'            "終了コードの節が日本語ラベル"
has "$H"  '>標準出力<'              "標準出力の節が日本語ラベル"
has "$H"  '>使用例<'                "使用例の節が日本語ラベル"
hasnt "$H" '>Arguments<'           "英語見出し Arguments を残さない"
hasnt "$H" '>Exit codes<'          "英語見出し Exit codes を残さない"
hasnt "$H" 'Function has no arguments' "英語の定型文を残さない"
has "$H"  '引数を取らない'          "@noargs は日本語で示す"
has "$H"  '<p class="sum">'        "関数見出しに役割の1行説明が添う"
has "$H"  'blob/main/scripts/sample-a.sh#L' "関数から定義元（行番号つき）へリンクする"
has "$H"  'blob/main/mape/sample-b.sh'      "モジュールから定義元へリンクする"
has "$H"  '内部ヘルパー 1 件は非表示'        "@internal の非表示件数を明示する"
hasnt "$H" '>Index<'               "shdoc の Index 節は本文に残さない（索引に統合）"

# --- 冒頭の読み方・ページの体裁 ---------------------------------------------
has "$H" 'このページの読み方'        "冒頭に読み方がある"
has "$H" 'bash scripts/build-docs.sh --check' "再生成・乖離検査のコマンドを示す"
has "$H" 'href="reference.html"'    "ヘッダナビに現在地がある"
hasnt "$H" 'href="guide.html"'      "存在しないページへリンクしない"
has "$H" 'aria-current="page"'      "現在地を示す"
has "$H" 'id="tt"'                  "テーマ切替がある"
has "$H" 'data-theme'               "light/dark のテーマトークンがある"

# --- ピラミッド原則の構成（.claude/rules/docs.md / Round 12 #50） ------------
# 生成物そのものを本番の構成検査にかける（結論段落・1文・見出し階層・用語の初出注釈）
( cd "$F" && bash tools/check-docs-structure.sh >/dev/null 2>&1 )
ok $? "生成物がピラミッド原則の構成検査に適合する"
# 検査器が「合格に倒れているだけ」でないことを確かめる（結論段落を壊せば落ちる）
D="$work/pyramid"; mkfix "$D"; bd "$D"
sed -i 's/<p class="sum answer">/<p class="sum">/' "$D/docs/reference.html"
( cd "$D" && bash tools/check-docs-structure.sh >/dev/null 2>&1 )
ng $? "結論段落を外した HTML は構成検査に落ちる（検査が効いている）"

# ページ全体の結論（見出しの直後に1文）
has "$H" '<p class="answer lead">' "ページ先頭の見出しの直後が結論段落"
# モジュール節の結論は @brief の先頭1文
eq "$(modanswer "$H" mod-scripts-sample-d-sh)" "結論は先頭1文。" "モジュールの結論は @brief の先頭1文"
has "$H" '2文目以降は続く段落に回す。' "結論から外れた文も本文に残る（情報を消さない）"
eq "$(modanswer "$H" mod-scripts-sample-e-sh)" "括弧つきの結論" "括弧の中に句点があれば括弧の手前で切る（結論は句点1つまで）"
has "$H" '（中に。を含む）。ここから2文目。' "括弧ごと後ろの段落に回す（本文の文字は書き換えない）"
eq "$(modanswer "$H" mod-scripts-sample-f-sh)" "1行説明が未整備（ソースに @brief を書く）。" \
  "@brief が無くても結論段落を欠かさない（構成検査に落ちない）"
# 見出しの直後は必ず結論段落（注記より前）
gawk '
  index($0, "<section class=\"mod\" id=") { insec = 1; seenh3 = 0; next }
  insec && index($0, "<h3 class=\"mod-h\">") { seenh3 = 1; next }
  insec && seenh3 && $0 ~ /^<p / {
    if ($0 !~ /class="sum answer"/) bad++
    insec = 0; seenh3 = 0
  }
  END { exit (bad > 0) }
' "$H"
ok $? "モジュール見出しの直後は必ず結論段落（p.sum.answer）"
# 回帰: 索引の描画（inline_only）でも結論段落の保険が動き、nav の直後に迷子の段落が出ていた
eq "$(grep -c 'class="sum answer"' "$H")" "$(grep -c '<section class="mod" id=' "$H")" \
  "結論段落の数はモジュール数と一致する（索引側に紛れ込まない）"
[ "$(lineof "$H" '注記の無いフック')" -lt "$(lineof "$H" 'shdoc 注記が未整備')" ] \
  && pass "注記は結論のあとに出る" || bad "注記が結論より前に出ている"
# 用語の初出注釈（title は .claude/rules/docs.md の用語集と完全一致させる）
has "$H" '<abbr title="シェルスクリプトのコメントから API リファレンスを生成するツール（MIT）">shdoc</abbr>' \
  "用語 shdoc の初出に注釈が付く"
has "$H" '<abbr title="判断に必要な情報が欠けたとき、許可ではなく停止の側に倒す設計">fail-closed</abbr>' \
  "用語 fail-closed の初出に注釈が付く"
[ "$(grep -n '<abbr title=' "$H" | tail -1 | sed 's/:.*//')" -lt "$(lineof "$H" '<nav class="toc"')" ] \
  && pass "用語注釈はページ冒頭にまとまる（索引・本文は注釈で汚さない）" \
  || bad "生成される本文側に用語注釈が混ざっている"

# --- HTML エスケープ ---------------------------------------------------------
hasnt "$H" '<script>alert'      "生の <script> を出力しない"
hasnt "$H" '<b>bold</b>'        "生の HTML タグを素通ししない"
has "$H"  '&lt;script&gt;'      "< > をエスケープする"
has "$H"  '&amp;&amp;'          "& をエスケープする"
has "$H"  '&quot;'              '" をエスケープする'
# 索引（1行説明）側でもエスケープされている
has "$H"  '<span class="d">危険文字 &amp; &lt; &gt; &quot;' "索引の1行説明もエスケープする"

# --- 冪等性 ------------------------------------------------------------------
c1=$(cksum < "$H"); bd "$F"; c2=$(cksum < "$H")
eq "$c2" "$c1" "2回生成しても同一（冪等）"

# --- 決定論性（ロケール非依存） ---------------------------------------------
( cd "$F" && LC_ALL=C bash scripts/build-docs.sh >/dev/null 2>&1 ); lc=$(cksum < "$H")
( cd "$F" && LC_ALL=C.UTF-8 LANG=C.UTF-8 bash scripts/build-docs.sh >/dev/null 2>&1 ); lu=$(cksum < "$H")
eq "$lu" "$lc" "LC_ALL=C と C.UTF-8 で出力が同じ"
( cd "$F" && LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8 bash scripts/build-docs.sh >/dev/null 2>&1 ); lj=$(cksum < "$H")
eq "$lj" "$lc" "未導入ロケール指定でも出力が同じ"
# 生成日時・ホスト名・作業ディレクトリの絶対パスを混ぜない（混ぜると毎回 drift する）
hasnt "$H" "$(date +%Y-%m-%dT)" "生成日時を埋め込まない"
hasnt "$H" '/tmp/'              "作業ディレクトリの絶対パスを埋め込まない"
hasnt "$H" "$(hostname)"        "ホスト名を埋め込まない"

# --- 乖離検知 ----------------------------------------------------------------
printf '\n# @description 後から足した関数\n# @noargs\nlater_fn() { :; }\n' >> "$F/scripts/sample-a.sh"
bd "$F" --check; ng $? "ソース変更を検出する"
bd "$F"; bd "$F" --check; ok $? "再生成で合格に戻る"
has "$H" 'later_fn' "追加した関数が生成物に反映される"

printf '<!-- drift -->\n' >> "$H"
bd "$F" --check; ng $? "生成物の改変を検出する"
sum_drift=$(cksum < "$H")
bd "$F" --check
eq "$(cksum < "$H")" "$sum_drift" "--check は reference.html を書き換えない（読み取り専用）"
bd "$F"; bd "$F" --check; ok $? "再生成で改変が解消する"

rm -f "$H"
bd "$F" --check; ng $? "生成物が無ければ失敗する"
eq "$(bdo "$F" --check | grep -c '存在しない')" "1" "生成物が無い旨をメッセージで示す"
bd "$F"; ok $? "生成物が無くても生成できる"

# --- 引数の扱い（誤記で検査が生成に化けない） --------------------------------
printf '<!-- drift -->\n' >> "$H"
sum_typo=$(cksum < "$H")
( cd "$F" && bash scripts/build-docs.sh --chek >/dev/null 2>&1 ); rc=$?
eq "$rc" "2" "未知の引数は使い方エラー(exit 2)"
eq "$(cksum < "$H")" "$sum_typo" "未知の引数では生成物を書き換えない"
( cd "$F" && bash scripts/build-docs.sh --check extra >/dev/null 2>&1 ); rc=$?
eq "$rc" "2" "引数が多い場合も使い方エラー(exit 2)"
bd "$F" --check; ng $? "誤記の後も乖離は残っている（隠蔽されない）"
bd "$F"

# --- gawk 不在（判定不能を合格に倒さない。Round 9 #40） ----------------------
# build-docs.sh が使うコマンドは揃え、gawk だけを欠いた PATH
sb=$(mkbin bash cat cp diff dirname grep mktemp rm sed sort tr)
out=$( cd "$F" && PATH="$sb" bash scripts/build-docs.sh --check 2>&1 ); rc=$?
ng "$rc" "gawk 不在では --check が失敗する（黙って合格しない）"
case "$out" in *gawk*) pass "gawk 不在の理由をメッセージで示す";; *) bad "gawk 不在の理由が示されない（出力: $out）";; esac
case "$out" in *同期OK*) bad "gawk 不在なのに同期OKと表示する";; *) pass "gawk 不在で同期OKと表示しない";; esac
sum_nogawk=$(cksum < "$H")
( cd "$F" && PATH="$sb" bash scripts/build-docs.sh >/dev/null 2>&1 ); rc=$?
ng "$rc" "gawk 不在では生成も失敗する"
eq "$(cksum < "$H")" "$sum_nogawk" "gawk 不在の生成失敗で既存の生成物を壊さない"
rm -rf "$sb"

# --- vendoring した shdoc の欠落 --------------------------------------------
S="$work/noshdoc"; mkfix "$S"; bd "$S"
rm -f "$S/tools/shdoc/shdoc"
bd "$S" --check; ng $? "shdoc 本体が無ければ --check は失敗する"
bd "$S"; ng $? "shdoc 本体が無ければ生成も失敗する"

# --- 対象が1件も無い ---------------------------------------------------------
# 生成器自身も対象（scripts/*.sh）なので、拡張子を外した写しから起動して対象0件を作る
E="$work/empty"; mkfix "$E"
rm -f "$E/scripts/"*.sh "$E/mape/"*.sh "$E/.claude/hooks/"*.sh
cp scripts/build-docs.sh "$E/scripts/build-docs"
( cd "$E" && bash scripts/build-docs >/dev/null 2>&1 ); rc=$?
ng "$rc" "対象が1件も無ければ失敗する（空ページを黙って作らない）"
[ ! -f "$E/docs/reference.html" ] && pass "対象0件では reference.html を作らない" || bad "対象0件で空の reference.html を作った"

# --- パスに空白を含むルート --------------------------------------------------
P="$work/sp ace root"; mkfix "$P"
bd "$P"; ok $? "パスに空白があっても生成できる"
bd "$P" --check; ok $? "パスに空白があっても --check 合格"
printf '\n# @description 空白パスでの追加\n# @noargs\nspaced_fn() { :; }\n' >> "$P/scripts/sample-a.sh"
bd "$P" --check; ng $? "パスに空白があっても乖離を検出する"

# --- 解決できないページ内リンクは素のテキストに落とす（リンク切れを出荷しない） ----
# 回帰: shdoc の `@see [x](#x)` は、モジュール接頭辞つきの id に解決できないことがある。
# 実際に mape/lib.sh の @see 由来で reference.html に 3 件のリンク切れが出荷されていた。
# 生成器が飛び先の無い <a href="#..."> を中身のテキストへ落とすことを固定する。
L="$work/deadlink"; mkfix "$L"
printf '\n# @description リンク検査用\n# @see [存在しない見出し](#no-such-anchor-xyz)\n# @noargs\nlinky_fn() { :; }\n' >> "$L/scripts/sample-a.sh"
bd "$L"; ok $? "解決できない @see があっても生成できる"
grep -q 'no-such-anchor-xyz' "$L/docs/reference.html" \
  && bad "飛び先の無いページ内リンクを出荷している" \
  || pass "飛び先の無いページ内リンクを出荷しない"
grep -q '存在しない見出し' "$L/docs/reference.html" \
  && pass "リンクを外してもテキストは残す（情報を消さない）" \
  || bad "リンクを外すときにテキストごと消している"
# 生成物全体でページ内リンクの飛び先が全て存在すること（総合検査）。
# 依存を増やさないよう gawk で行う（生成器と同じ前提ツール）。
gawk '
  NR == FNR {
    s = $0
    while (match(s, /id="[^"]*"/)) { ids[substr(s, RSTART + 4, RLENGTH - 5)] = 1; s = substr(s, RSTART + RLENGTH) }
    next
  }
  {
    s = $0
    while (match(s, /href="#[^"]*"/)) {
      a = substr(s, RSTART + 7, RLENGTH - 8)
      if (!(a in ids)) { bad++ }
      s = substr(s, RSTART + RLENGTH)
    }
  }
  END { exit (bad > 0) }
' "$L/docs/reference.html" "$L/docs/reference.html"
ok $? "生成物にページ内リンク切れが無い"

echo ""
if [ "$fail" -ne 0 ]; then
  echo "test-build-docs: 失敗" >&2
  exit 1
fi
echo "test-build-docs: すべて合格"
