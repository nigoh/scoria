#!/usr/bin/env bash
# @file scripts/test-docs-structure.sh
# @brief check-docs-structure.sh の動作テスト（一時フィクスチャで正常系・異常系を検証）。
# @description
#   check-docs-structure.sh の動作テスト。一時フィクスチャで検査項目ごとに「正常系1・異常系1以上」を作り、
#   **違反を作れば本当に落ちる**ことを確かめる（検査が嘘をつかない証明）。
#   check.sh から呼ばれる。判定ロジックを変えたら再発防止ケースを追加すること。
# @exitcode 0 全ケース合格
# @exitcode 1 いずれかのケースが不合格
# @stdout ケースごとの PASS 行
# @stderr 不合格ケースの FAIL 行
set -u

export LC_ALL=C
export LANG=C

cd "$(dirname "$0")/.." || exit 1

fail=0
# @description ケースの合格を報告する。
# @internal
# @arg $1 string ケースの説明
# @stdout "PASS: 説明"
pass() { echo "PASS: $1"; }
# @description ケースの不合格を報告し fail フラグを立てる。
# @internal
# @arg $1 string ケースの説明
# @set fail int 1
# @stderr "FAIL: 説明"
bad()  { echo "FAIL: $1" >&2; fail=1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# @description main の中身を受け取り、最小の HTML ページを書く。
#   head / nav / footer には用語（deb・ADR）をわざと置く。これらは初出と数えない除外領域なので、
#   ここで誤検知が出ればテストが落ちる（除外規則の回帰テストを兼ねる）。
# @internal
# @arg $1 string 出力ファイル名
# @arg $2 string main の中身
page() {
  mkdir -p docs
  {
    printf '%s\n' '<!DOCTYPE html>' '<html lang="ja">'
    printf '%s\n' '<head><meta charset="utf-8"><title>deb の ADR テスト</title></head>'
    printf '%s\n' '<body>' '<nav><a href="index.html">deb の概要</a></nav>' '<main>'
    printf '%s\n' "$2"
    printf '%s\n' '</main>' '<footer>deb フッター · ADR</footer>' '</body>' '</html>'
  } > "docs/$1"
}

# 規約を満たす節（結論 → 図 → 本文）。用語は含めない（各ケースで足す）。
GOOD='<section id="a">
  <p class="eyebrow">前置き</p>
  <h2>これは何か</h2>
  <p class="answer">土台である。</p>
  <figure><img src="x.png" alt="図"><figcaption>図の説明</figcaption></figure>
  <p>補足の文。</p>
</section>'

# @description 一時ディレクトリにフィクスチャを組み立て、その中で check-docs-structure.sh を実行する。
#   check-docs-structure.sh は $0/.. へ cd するため、scripts/ を1階層下に置いてフィクスチャのルートを指させる。
# @internal
# @arg $1 string フィクスチャを構築する関数名（フィクスチャのルートで実行される）
# @arg $2 string ケース名（一時ディレクトリ名に使う）
# @stdout 検査の出力（stdout + stderr を合流させたもの）
# @exitcode * check-docs-structure.sh の終了コードをそのまま返す
run_in_fixture() {
  local dir="$work/$2"
  mkdir -p "$dir/scripts" "$dir/.claude/rules"
  cp scripts/check-docs-structure.sh "$dir/scripts/"
  # 検査0（用語集の一致）が実データを見に行かないよう、規約も本物をフィクスチャへ複製する。
  cp .claude/rules/docs.md "$dir/.claude/rules/"
  ( cd "$dir" && "$1" && bash "$dir/scripts/check-docs-structure.sh" ) 2>&1
}

# @description フィクスチャを実行し、終了コードが期待どおりかを検証する。
# @internal
# @arg $1 string フィクスチャ構築関数名
# @arg $2 string ケース名
# @arg $3 int 期待する終了コード（0=合格 / 1=違反 / 2=使い方の誤り）
# @arg $4 string ケースの説明
# @set fail int 不一致なら 1
expect() {
  local out rc
  out=$(run_in_fixture "$1" "$2"); rc=$?
  if [ "$rc" -eq "$3" ]; then pass "$4"; else bad "$4（期待 exit=$3 / 実際 exit=$rc / 出力: $out）"; fi
}

# @description フィクスチャを実行し、終了コードと出力メッセージの両方を検証する。
# @internal
# @arg $1 string フィクスチャ構築関数名
# @arg $2 string ケース名
# @arg $3 int 期待する終了コード
# @arg $4 string 出力に含まれるべき文字列
# @arg $5 string ケースの説明
# @set fail int 不一致なら 1
expect_msg() {
  local out rc
  out=$(run_in_fixture "$1" "$2"); rc=$?
  if [ "$rc" -ne "$3" ]; then bad "$5（期待 exit=$3 / 実際 exit=$rc / 出力: $out）"; return; fi
  case "$out" in
    *"$4"*) pass "$5" ;;
    *) bad "$5（出力に「$4」が無い: $out）" ;;
  esac
}

# @description フィクスチャを実行し、NG 行が指定件数以上あるかを検証する（1件目で打ち切らない証明）。
# @internal
# @arg $1 string フィクスチャ構築関数名
# @arg $2 string ケース名
# @arg $3 int 期待する NG 行の最小件数
# @arg $4 string ケースの説明
# @set fail int 不足なら 1
expect_ng_count() {
  local out n
  out=$(run_in_fixture "$1" "$2")
  n=$(printf '%s\n' "$out" | grep -c 'NG(docs):')
  if [ "$n" -ge "$3" ]; then pass "$4"; else bad "$4（NG は $3 件以上のはずが $n 件）"; fi
}

# --- 1. 正常系ベースラインと入口の振る舞い -----------------------------------

# @description ケースA: 規約を満たすページ → 合格
caseA() { page reference.html "$GOOD"; }
expect caseA A 0 "規約を満たすページ→合格"

# @description ケースB: 対象 HTML が1つも無い → 合格（黙って通さず明示する）
caseB() { : ; }
expect_msg caseB B 0 "対象ファイルなし" "対象HTMLなし→合格と明示"

# @description ケースC: 合格メッセージに検査件数が出る
caseC() { page reference.html "$GOOD"; }
expect_msg caseC C 0 "section 1 件" "合格メッセージに件数が出る"

# @description ケースD: 引数を渡すと使い方の誤り（未知引数を検査に倒さない）
caseD() { page reference.html "$GOOD"; }
run_out=$( { cd "$work" && mkdir -p D/scripts && cp "$OLDPWD/scripts/check-docs-structure.sh" D/scripts/ && cd D && bash scripts/check-docs-structure.sh --all; } 2>&1 )
[ $? -eq 2 ] && pass "引数付き実行→exit 2" || bad "引数付き実行→exit 2（出力: $run_out）"

# @description ケースE: gawk が無い環境では合格に倒さず明示メッセージで落ちる（fail-closed）
mkdir -p "$work/E/scripts" "$work/E/bin"
cp scripts/check-docs-structure.sh "$work/E/scripts/"
# gawk **だけ**が無い状態を作る（PATH を絞り、検査に必要な他のコマンドは残す）。
ln -s "$(command -v dirname)" "$work/E/bin/dirname"
bash_bin=$(command -v bash)
out_e=$( cd "$work/E" && page reference.html "$GOOD" && PATH="$work/E/bin" "$bash_bin" scripts/check-docs-structure.sh 2>&1 )
rc_e=$?
if [ "$rc_e" -eq 1 ]; then pass "gawk 欠落→非ゼロ終了"; else bad "gawk 欠落→非ゼロ終了（期待 exit=1 / 実際 exit=$rc_e / 出力: $out_e）"; fi
case "$out_e" in
  *"gawk が見つからない"*) pass "gawk 欠落→明示メッセージ" ;;
  *) bad "gawk 欠落→明示メッセージ（出力: $out_e）" ;;
esac

# --- 2. 検査1: 節は結論の段落から始まる --------------------------------------

# @description ケースF: 見出しの直後がただの <p> → 失敗
caseF() { page reference.html '<section id="a"><h2>問い</h2><p>結論ではない段落。</p></section>'; }
expect_msg caseF F 1 'でない' "見出し直後がただの p→失敗"

# @description ケースG: 見出しの直後が <div> → 失敗
caseG() { page reference.html '<section id="a"><h2>問い</h2><div><p class="answer">結論。</p></div></section>'; }
expect caseG G 1 "見出し直後が div→失敗"

# @description ケースH: 見出しの直後に地の文がある → 失敗
caseH() { page reference.html '<section id="a"><h2>問い</h2>地の文<p class="answer">結論。</p></section>'; }
expect_msg caseH H 1 '地の文' "見出し直後の地の文→失敗"

# @description ケースI: 見出しが <header> に包まれ、結論がその外でも合格（閉じタグは読み飛ばす）
caseI() { page reference.html '<section id="a"><header><p class="eyebrow">前置き</p><h2>問い</h2></header><p class="answer">結論。</p></section>'; }
expect caseI I 0 "header 越しの結論→合格"

# @description ケースJ: 見出しを持たない構造用 section は対象外 → 合格
caseJ() { page reference.html '<section class="wrap"><div>レイアウトだけの箱</div></section>'; }
expect caseJ J 0 "見出しなし section は対象外→合格"

# @description ケースK: 入れ子 section の内側が違反 → 失敗
caseK() { page reference.html '<section id="o"><h2>外</h2><p class="answer">外の結論。</p><section id="i"><h3>内</h3><p>結論でない。</p></section></section>'; }
expect_msg caseK K 1 '#i' "入れ子 section の内側の違反→失敗"

# @description ケースL: 入れ子 section が両方とも規約どおり → 合格
caseL() { page reference.html '<section id="o"><h2>外</h2><p class="answer">外の結論。</p><section id="i"><h3>内</h3><p class="answer">内の結論。</p><p>本文。</p></section></section>'; }
expect caseL L 0 "入れ子 section が両方規約どおり→合格"

# @description ケースM: 結論段落が無いまま section が閉じる → 失敗
caseM() { page reference.html '<section id="a"><h2>問い</h2></section>'; }
expect caseM M 1 "結論段落が無い section→失敗"

# --- 3. 検査2: 結論は1文 ------------------------------------------------------

# @description ケースN: 結論に句点が2つ → 失敗
caseN() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">一文目。二文目。</p></section>'; }
expect_msg caseN N 1 '2 文' "結論が2文→失敗"

# @description ケースO: 結論の句点が1つ → 合格
caseO() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論は一文。</p></section>'; }
expect caseO O 0 "結論が1文→合格"

# @description ケースP: 結論段落が空 → 失敗
caseP() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">   </p></section>'; }
expect_msg caseP P 1 '空' "空の結論段落→失敗"

# @description ケースQ: 結論内のインライン要素を跨いだ2文も数える → 失敗
caseQ() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">一文目<strong>強調</strong>。二文目。</p></section>'; }
expect caseQ Q 1 "インライン要素を跨いだ2文→失敗"

# @description ケースR: 句点が無い体言止めの結論 → 合格（1文以内なので許す）
caseR() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">一言でいえば土台</p></section>'; }
expect caseR R 0 "句点なしの結論→合格"

# --- 4. 検査3: 見出し階層を飛ばさない ----------------------------------------

# @description ケースS: h2 の次に h4 → 失敗
caseS() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><h4>飛んだ見出し</h4><p class="answer">結論。</p></section>'; }
expect_msg caseS S 1 '飛ばしている' "h2 の次に h4→失敗"

# @description ケースT: h2→h3→h2→h3 は合格（浅い階層へ戻るのは可）
caseT() { page reference.html '<section id="a"><h2>一</h2><p class="answer">結論。</p><h3>子</h3><p class="answer">結論。</p></section><section id="b"><h2>二</h2><p class="answer">結論。</p><h3>子</h3><p class="answer">結論。</p></section>'; }
expect caseT T 0 "階層を戻る見出し→合格"

# --- 5. 検査4: 図は文より先 ---------------------------------------------------

# @description ケースU: 本文段落の後に図がある → 失敗
caseU() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>本文。</p><figure><img src="x.png" alt="図"></figure></section>'; }
expect_msg caseU U 1 '図が本文より後' "図が本文より後→失敗"

# @description ケースV: 結論の直後に図 → 合格
caseV() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><figure><img src="x.png" alt="図"></figure><p>本文。</p></section>'; }
expect caseV V 0 "結論の直後に図→合格"

# @description ケースW: figcaption 内の <p> を本文段落と数えない → 合格
caseW() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><figure><img src="x.png" alt="図"><figcaption><p>図の説明。</p></figcaption></figure><p>本文。</p></section>'; }
expect caseW W 0 "figcaption 内の p を本文と数えない→合格"

# @description ケースX: 図が無ければ本文だけでも合格
caseX() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>本文。</p></section>'; }
expect caseX X 0 "図なしの節→合格"

# @description ケースY: 次節の eyebrow を前の見出しブロックの本文と誤認しない → 合格
caseY() { page reference.html "$GOOD"$'\n''<section id="b"><p class="eyebrow">前置き</p><h2>次</h2><p class="answer">結論。</p><figure><img src="y.png" alt="図"></figure><p>本文。</p></section>'; }
expect caseY Y 0 "次節の eyebrow を誤認しない→合格"

# @description ケースZ: 見出しブロック単位で判定する（h3 ブロックの図が本文より後）→ 失敗
caseZ() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><figure><img src="x.png" alt="図"></figure><h3>子</h3><p class="answer">結論。</p><p>本文。</p><figure><img src="y.png" alt="図"></figure></section>'; }
expect caseZ Z 1 "h3 ブロックの図が本文より後→失敗"

# --- 6. 検査5: 用語の初出に注釈 ----------------------------------------------

# @description ケースAA: 用語が注釈なしで本文に初出 → 失敗
caseAA() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>ここで品質ゲートの話をする。</p></section>'; }
expect_msg caseAA AA 1 '初出に注釈が無い' "用語の無注釈初出→失敗"

# @description ケースAB: <abbr title> で注釈 → 合格
caseAB() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>ここで <abbr title="check.sh が走らせる検査">品質ゲート</abbr> の話をする。</p></section>'; }
expect caseAB AB 0 "abbr title で注釈→合格"

# @description ケースAC: class="term" で注釈 → 合格
caseAC() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>ここで <span class="term" title="check.sh が走らせる検査">品質ゲート</span> の話をする。</p></section>'; }
expect caseAC AC 0 "class=term で注釈→合格"

# @description ケースAD: title の無い <abbr> は注釈と数えない → 失敗
caseAD() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>ここで <abbr>品質ゲート</abbr> の話をする。</p></section>'; }
expect caseAD AD 1 "title なし abbr は注釈と数えない→失敗"

# @description ケースAE: <code> の中の用語は初出と数えない → 合格
caseAE() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>実行するのは <code>品質ゲート</code> だけ。</p></section>'; }
expect caseAE AE 0 "code 内の用語は初出と数えない→合格"

# @description ケースAF: 見出しの中の用語は初出と数えない → 合格
caseAF() { page reference.html '<section id="a"><h2>品質ゲートとは</h2><p class="answer">結論。</p></section>'; }
expect caseAF AF 0 "見出し内の用語は初出と数えない→合格"

# @description ケースAG: <svg> の中のラベルは初出と数えない → 合格
caseAG() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><figure><svg viewBox="0 0 10 10"><text x="1" y="2">品質ゲート</text></svg></figure></section>'; }
expect caseAG AG 0 "svg 内のラベルは初出と数えない→合格"

# @description ケースAH: 用語集（class="glossary"）の中の定義は初出と数えない → 合格
caseAH() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><dl class="glossary"><dt>品質ゲート</dt><dd>check.sh が走らせる検査。</dd></dl></section>'; }
expect caseAH AH 0 "用語集内の定義は初出と数えない→合格"

# @description ケースAI: 語の一部（debug）を用語 deb の初出と数えない → 合格
caseAI() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>ここでは debug の話をする。</p></section>'; }
expect caseAI AI 0 "debug を deb と数えない→合格"

# @description ケースAJ: 注釈済みの後に同じ語が無注釈で再出現しても合格（初出だけ見る）
caseAJ() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p><abbr title="検査">品質ゲート</abbr> はこう動く。</p><p>品質ゲートは毎回走る。</p></section>'; }
expect caseAJ AJ 0 "2回目以降の無注釈→合格"

# @description ケースAK: 無注釈が先・注釈が後 → 失敗（初出で注釈する）
caseAK() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>品質ゲートは毎回走る。</p><p><abbr title="検査">品質ゲート</abbr> はこう動く。</p></section>'; }
expect caseAK AK 1 "無注釈が先・注釈が後→失敗"

# @description ケースAL: 広い語（Stop フック）を注釈すれば、含まれる語（フック）も満たす → 合格
caseAL() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><p>まず <abbr title="停止時に走る仕掛け">Stop フック</abbr> が動く。</p></section>'; }
expect caseAL AL 0 "広い語の注釈で含まれる語も満たす→合格"

# --- 7. 検査6: reduced-motion -------------------------------------------------

# @description ケースAM: @keyframes があるのに prefers-reduced-motion が無い → 失敗
caseAM() {
  page reference.html "$GOOD"
  printf '%s\n' '<style>@keyframes blink{0%{opacity:1}100%{opacity:0}}</style>' >> docs/reference.html
}
expect_msg caseAM AM 1 'prefers-reduced-motion' "@keyframes だけ→失敗"

# @description ケースAN: @keyframes と prefers-reduced-motion が両方ある → 合格
caseAN() {
  page reference.html "$GOOD"
  printf '%s\n' '<style>@keyframes blink{0%{opacity:1}100%{opacity:0}}' \
    '@media (prefers-reduced-motion: reduce){*{animation:none!important}}</style>' >> docs/reference.html
}
expect caseAN AN 0 "@keyframes + reduced-motion→合格"

# @description ケースAO: アニメーションを使わないページは reduced-motion の指定が無くても合格
caseAO() { page reference.html "$GOOD"; }
expect caseAO AO 0 "アニメーション無し→合格"

# --- 8. 誤検知よけ・複数ファイル・報告の網羅 ---------------------------------

# @description ケースAP: HTML コメント内の偽タグを構造と誤認しない → 合格
caseAP() { page reference.html '<!-- <section id="x"><h2>コメント</h2><p>偽の本文</p></section> -->'"$GOOD"; }
expect caseAP AP 0 "コメント内の偽タグを無視→合格"

# @description ケースAQ: script 内の文字列を構造と誤認しない → 合格
caseAQ() { page reference.html "$GOOD"$'\n''<script>var s = "<section><h2>にせ</h2><p>本文</p></section>";</script>'; }
expect caseAQ AQ 0 "script 内の文字列を無視→合格"

# @description ケースAR: <pre> のコード例に含まれる用語を初出と数えない → 合格
caseAR() { page reference.html '<section id="a"><h2>問い</h2><p class="answer">結論。</p><pre>bash scripts/check.sh  # 品質ゲート</pre></section>'; }
expect caseAR AR 0 "pre 内の用語を無視→合格"

# @description ケースAS: <main> が無いページは文書全体を検査する（違反を見逃さない）
caseAS() {
  mkdir -p docs
  {
    printf '%s\n' '<!DOCTYPE html>' '<html lang="ja">' '<head><meta charset="utf-8"><title>t</title></head>' '<body>'
    printf '%s\n' '<section id="a"><h2>問い</h2><p>結論ではない。</p></section>'
    printf '%s\n' '</body>' '</html>'
  } > docs/reference.html
}
expect caseAS AS 1 "main が無くても検査する→失敗を検知"

# @description ケースAT: guide.html も検査対象（reference.html だけ見ていない）
caseAT() {
  page reference.html "$GOOD"
  page guide.html '<section id="g"><h2>問い</h2><p>結論ではない。</p></section>'
}
expect_msg caseAT AT 1 'guide.html' "guide.html の違反も検知"

# @description ケースAU: reference.html も検査対象
caseAU() {
  page guide.html "$GOOD"
  page reference.html '<section id="r"><h2>問い</h2><p>結論ではない。</p></section>'
}
expect_msg caseAU AU 1 'reference.html' "reference.html の違反も検知"

# @description ケースAV: 違反は1件目で打ち切らず全件を報告する
caseAV() {
  page reference.html '<section id="a"><h2>問い</h2><p>結論でない。</p><h4>飛んだ</h4><p class="answer">一文目。二文目。</p></section>'
}
expect_ng_count caseAV AV 3 "違反を全件報告する"

# @description ケースAW: 違反の報告に「ファイル:行」が付く
caseAW() { page reference.html "$GOOD"$'\n''<section id="b"><h2>問い</h2><p>結論でない。</p></section>'; }
expect_msg caseAW AW 1 'reference.html:' "報告にファイル:行が付く"

# @description ケースAX: 3ファイルすべて規約どおりなら合格（件数も合算される）
caseAX() {
  page reference.html "$GOOD"
  page guide.html "$GOOD"
}
expect_msg caseAX AX 0 "HTML 2 件" "2ファイル合格と件数合算"

# --- 9. 検査0: 用語集の正本が規約と検査スクリプトで一致している ---------------

# @description ケースAY: 規約と検査スクリプトの用語集が一致していれば合格（正常系）
caseAY() { page reference.html "$GOOD"; }
expect caseAY AY 0 "用語集が規約と一致していれば合格"

# @description ケースAZ: 規約側に語を足すと落ちる（検査されない語が生まれるのを防ぐ）
caseAZ() {
  page reference.html "$GOOD"
  sed -i 's|`shdoc`|`shdoc` / `未検査語`|' .claude/rules/docs.md
}
expect_msg caseAZ AZ 1 "用語集が" "規約にだけ語を足すと落ちる"

# @description ケースBA: 検査スクリプト側に語を足すと落ちる（規約に無い語で落とさない）
caseBA() {
  page reference.html "$GOOD"
  sed -i 's|^\([[:space:]]*\)TERMS\[++TN\] = "shdoc"|\1TERMS[++TN] = "shdoc"\n\1TERMS[++TN] = "無規約語"|' scripts/check-docs-structure.sh
}
expect_msg caseBA BA 1 "用語集が" "検査側にだけ語を足すと落ちる"

# @description ケースBB: 語の並び順が食い違うと落ちる（同じ集合でも順が違えば不一致）
caseBB() {
  page reference.html "$GOOD"
  sed -i 's|`deb` / `steering`|`steering` / `deb`|' .claude/rules/docs.md
}
expect_msg caseBB BB 1 "用語集が" "並び順の食い違いを検知"

# @description ケースBC: 規約ファイルが無ければ落ちる（照合不能を合格に倒さない = fail-closed）
caseBC() {
  page reference.html "$GOOD"
  rm -f .claude/rules/docs.md
}
expect_msg caseBC BC 1 "用語集の正本を照合できない" "規約ファイル欠落は fail-closed"

# @description ケースBD: 規約から用語集を読み取れなければ落ちる（見出しを消しても素通りしない）
caseBD() {
  page reference.html "$GOOD"
  sed -i 's|用語集の正本|用語の一覧|' .claude/rules/docs.md
}
expect_msg caseBD BD 1 "用語集を読み取れない" "用語集を読み取れなければ fail-closed"

if [ "$fail" -ne 0 ]; then
  echo "docs-structure テスト: 失敗" >&2
  exit 1
fi
echo "docs-structure テスト: 全ケース合格"
