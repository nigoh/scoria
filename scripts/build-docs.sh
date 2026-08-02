#!/usr/bin/env bash
# @file scripts/build-docs.sh
# @brief シェルスクリプトのリファレンス（docs/reference.html）生成器
# @description
#   scripts/*.sh・mape/*.sh・.claude/hooks/*.sh のコメントを vendoring した shdoc
#   （tools/shdoc/shdoc・MIT）で Markdown 化し、単一の docs/reference.html にまとめる。
#
#   正本はシェルスクリプト側のコメントであり、docs/reference.html は生成物。手で編集しない。
#
#     bash scripts/build-docs.sh          … docs/reference.html を再生成する
#     bash scripts/build-docs.sh --check  … ソースと docs/reference.html の乖離を検査（差があれば exit 1）
#
#   「読んで分かる」ことを優先した構成にする:
#   1) モジュールを役割（品質ゲート / フック / MAPE-K / ツール / テスト）でグループ化する
#      （GROUP_DEFS が定義。どれにも当てはまらないファイルは「その他」に必ず出す＝黙って落とさない）
#   2) 索引に各関数の説明の先頭1文を添える（識別子の羅列にしない）
#   3) 索引を関数名・説明で絞り込む検索を付ける（依存ゼロの inline JS。無効でも全件見える）
#   4) 引数・終了コード・出力は日本語ラベルにし、定義元（GitHub の行番号）へリンクする
#
#   依存は gawk のみ（shdoc が `gawk -E` を要求する）。Markdown→HTML の変換は
#   外部ツールに頼らず下の MD2HTML（awk）で行う。gawk が無い環境では「判定不能」を
#   合格に倒さず、明示メッセージ付きで非ゼロ終了する（fail-closed）。
set -u

# 決定論性のためロケールを固定する。ファイル列挙順（glob/sort の照合順）・正規表現の
# 文字クラス・大文字小文字変換がロケールで揺れると、同じ入力から違う HTML が出てしまう。
export LC_ALL=C
export LANG=C

cd "$(dirname "$0")/.." || exit 1

OUT="docs/reference.html"
SHDOC="tools/shdoc/shdoc"
# リンク先は定数で持つ（git remote から取ると環境で出力が変わり決定論性が壊れる）
REPO="https://github.com/nigoh/scoria"
# 索引で関数一覧を畳む閾値。これを超えるモジュール（テストのケース関数群）は details を
# 閉じて出す。閉じても件数は見えるし JS 無しでも開ける（内容を消しはしない）。
FN_FOLD=24

# モジュールの役割グループ（この順に並ぶ）。`key|見出し|1行説明`。
# 説明は素のテキストで書く（索引と本文で同じに見せるため markdown 記法は使わない）。
GROUP_DEFS=$(cat <<'GROUP_DEFS_TXT'
gate|品質ゲート — CI と Stop フックが走らせる検査|scripts/check.sh が唯一の入口。土台の自己検証・一覧の同期・トレーサビリティを機械検証し、1つでも落ちれば作業を終えられない。ゲートを足すときはここに足す。
hook|フック — 実行時に割り込んで止める|Claude Code のツール実行や停止に割り込む。guard-* は保護ブランチへの push や保護ファイルの編集を exit 2 でブロックし、quality-gate は停止時に品質ゲートを走らせる。判定できないときは止める側に倒す。
mape|MAPE-K — 夜間セルフ改善|Monitor → Analyze → Plan の決定論スクリプトと安全機構（サーキットブレーカー・隔離・safe-state）。既定は読み取り専用で、書き込みは状態ディレクトリ配下だけ。
tool|ツール — 生成物のビルド|プラグイン配布物とこのリファレンスを生成する。生成物は手で編集せず、--check で正本（ソース）との乖離を検知する。
test|テスト — ゲートとフック自身の自己検証|一時フィクスチャで正常系と異常系を作り、「落ちるべきときに落ちる」ことを確かめる。実ツリーは書き換えない。関数はテストケースそのもの。
other|その他|上のどのグループにも当てはまらないスクリプト。分類は scripts/build-docs.sh の GROUP_DEFS に定義する。
GROUP_DEFS_TXT
)

mode="${1:-write}"

# 引数は「なし（生成）」か --check のみ。未知引数を write 扱いに倒すと `--chek` の綴り誤りで
# 「検査のつもりが黙って再生成して exit 0」となり乖離検知が無効化される（build-plugin.sh と同じ学び）。
case "$mode" in
  write|--check) ;;
  *) echo "usage: bash scripts/build-docs.sh [--check]（未知の引数: $mode）" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "usage: bash scripts/build-docs.sh [--check]（引数は1つまで）" >&2; exit 2
fi

# ---------------------------------------------------------------------------
# 前提ツールの確認（判定不能は安全側＝不合格に倒す）
# ---------------------------------------------------------------------------
tool_error() { # $1=理由
  echo "error: $1" >&2
  if [ "$mode" = "--check" ]; then
    echo "docs-sync: 失敗（検査不能。gawk を導入せよ: apt-get install -y gawk）" >&2
  else
    echo "reference.html 生成: 失敗" >&2
  fi
  exit 1
}

if ! command -v gawk >/dev/null 2>&1; then
  tool_error "gawk が見つからない（shdoc は gawk -E を要求する）。reference.html の生成・検査ができない"
fi
GAWK=$(command -v gawk)
if [ ! -f "$SHDOC" ]; then
  tool_error "$SHDOC が無い（vendoring した shdoc の欠落）"
fi
if ! printf '' | "$GAWK" -E "$SHDOC" >/dev/null 2>&1; then
  tool_error "gawk -E $SHDOC を実行できない（gawk が GNU awk でない可能性）"
fi

# ---------------------------------------------------------------------------
# 「先頭1文」の切り出し（awk 関数。MD2HTML / META_AWK / SPLIT1_AWK が共有する）。
# 括弧の外にある最初の「。」までを1文とみなす（「（… するため。…）」の途中で切らない）。
# ピラミッド原則（.claude/rules/docs.md）の「結論は1文」を満たす結論段落を作るのに使う。
# ---------------------------------------------------------------------------
read -r -d '' HEAD1_AWK <<'HEAD1_AWK_SRC'
function balance(t,   tmp, d) {
  d = 0
  tmp = t; d += gsub(/（/, "", tmp)
  tmp = t; d -= gsub(/）/, "", tmp)
  tmp = t; d += gsub(/\(/, "", tmp)
  tmp = t; d -= gsub(/\)/, "", tmp)
  tmp = t; d += gsub(/「/, "", tmp)
  tmp = t; d -= gsub(/」/, "", tmp)
  return d
}
function head1(s,   p, q, pos) {
  p = 1
  while (1) {
    q = index(substr(s, p), "。")
    if (q == 0) break
    pos = p + q - 1
    if (balance(substr(s, 1, pos - 1)) == 0) return substr(s, 1, pos + 2)
    p = pos + 3
  }
  return s
}
function dots(s,   t) { t = s; return gsub(/。/, "", t) }
# limit より前にある最初の開き括弧の位置（無ければ 0）
function firstbr(s, limit,   a, b, c, m) {
  a = index(s, "（"); b = index(s, "「"); c = index(s, "(")
  m = 0
  if (a > 0 && a < limit) m = a
  if (b > 0 && b < limit && (m == 0 || b < m)) m = b
  if (c > 0 && c < limit && (m == 0 || c < m)) m = c
  return m
}
# 結論段落（p.answer）に置く1文を切り出す。構成検査は「句点1つまで」を見るので、
# head1 が括弧の中の文を含んでしまう場合（例「A（B。C）。D。」）は括弧の手前で切り、
# 括弧以降は続く段落へ回す（本文の文字は書き換えず、切る位置だけを変える）。
function answer1(s,   h, p, cut) {
  h = head1(s)
  if (dots(h) <= 1) return h
  p = index(h, "。")
  cut = firstbr(h, p)
  if (cut > 1) {
    h = substr(h, 1, cut - 1)
    sub(/[[:space:]]+$/, "", h)
    if (h != "") return h
  }
  return substr(s, 1, p + 2)
}
HEAD1_AWK_SRC

# 1行を「先頭1文 <TAB> 残り」に割る（グループの1行説明を結論＋詳細に分けるのに使う）
read -r -d '' SPLIT1_BODY <<'SPLIT1_AWK_SRC'
{
  h = answer1($0)
  r = substr($0, length(h) + 1)
  sub(/^[[:space:]]+/, "", r)
  print h "\t" r
}
SPLIT1_AWK_SRC

# ---------------------------------------------------------------------------
# Markdown → HTML 変換器（awk）。shdoc が出す範囲だけを扱う:
#   見出し / コードフェンス / 箇条書き（継続行つき）/ 表 / 強調 / リンク / インラインコード。
# HTML エスケープを先に行い、その後に強調等のマークアップを解釈する（& < > " が壊さない）。
# 変数: prefix=アンカーの接頭辞, hshift=見出しレベルのシフト, droph1/droph1b=先頭 h1 の抑制対象,
#       srcpath=定義元の相対パス, repo=リポジトリ URL, linemap=関数名→行番号の TSV,
#       inline_only=1 なら「生HTML <TAB> markdown <TAB> 生HTML」の1行を組み立てるだけ
# 環境変数 MOD_NOTES=モジュールの注記 HTML。結論段落（p.sum.answer）の直後に差し込む
#       （見出しの直後は必ず結論＝ピラミッド原則。注記はそのあと）。
# ---------------------------------------------------------------------------
read -r -d '' MD2HTML <<'MD2HTML_AWK'
function esc(s) {
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  gsub(/"/, "\\&quot;", s)
  return s
}
function slug(s) {
  s = tolower(s)
  gsub(/[^a-z0-9_]+/, "-", s)
  sub(/^-+/, "", s)
  sub(/-+$/, "", s)
  return s
}
function bold(s,   out, p, q) {
  out = ""
  while ((p = index(s, "**")) > 0) {
    q = index(substr(s, p + 2), "**")
    if (q == 0) break
    out = out substr(s, 1, p - 1) "<strong>" substr(s, p + 2, q - 1) "</strong>"
    s = substr(s, p + 2 + q + 1)
  }
  return out s
}
# _..._ は前後が区切り文字のときだけ強調にする（mape_verify_knowledge のような識別子を壊さない）
function italic(s,   out, rest, pos, before, after, seg, nx) {
  out = ""; rest = s
  while (match(rest, /_[^_]+_/)) {
    pos = RSTART
    nx = pos + RLENGTH
    before = (pos == 1) ? " " : substr(rest, pos - 1, 1)
    after = (nx > length(rest)) ? " " : substr(rest, nx, 1)
    seg = substr(rest, pos + 1, RLENGTH - 2)
    if (before ~ /[ \t([]/ && after ~ /[ \t).,;:!?]/) {
      out = out substr(rest, 1, pos - 1) "<em>" seg "</em>"
    } else {
      out = out substr(rest, 1, nx - 1)
    }
    rest = substr(rest, nx)
  }
  return out rest
}
function href(url) {
  # ページ内リンク（shdoc の Index）はモジュールごとに接頭辞を付けて衝突を防ぐ
  if (substr(url, 1, 1) == "#") return "#" prefix "-" slug(substr(url, 2))
  return url
}
function links(s,   out, rest, pos, len, seg, cut, txt, url) {
  out = ""; rest = s
  while (match(rest, /\[[^]]*\]\([^)]*\)/)) {
    pos = RSTART; len = RLENGTH
    seg = substr(rest, pos, len)
    cut = index(seg, "](")
    txt = substr(seg, 2, cut - 2)
    url = substr(seg, cut + 2, length(seg) - cut - 2)
    out = out substr(rest, 1, pos - 1) "<a href=\"" href(url) "\">" txt "</a>"
    rest = substr(rest, pos + len)
  }
  return out rest
}
function markup(s) { return links(italic(bold(s))) }
function inline(s,   n, parts, i, out) {
  n = split(s, parts, "`")
  out = ""
  for (i = 1; i <= n; i++) {
    if (i % 2 == 1) out = out markup(esc(parts[i]))
    else out = out "<code>" esc(parts[i]) "</code>"
  }
  return out
}
# shdoc の英語見出しを日本語ラベルにする（表示だけ。id は英語の slug のまま＝リンクを壊さない）
function jp(t) {
  if (t == "Arguments") return "引数"
  if (t == "Exit codes") return "終了コード"
  if (t == "Output on stdout") return "標準出力"
  if (t == "Output on stderr") return "標準エラー出力"
  if (t == "Example") return "使用例"
  if (t == "Options") return "オプション"
  if (t == "Variables set") return "設定する変数"
  if (t == "See also") return "関連"
  if (t == "Overview") return "概要"
  return t
}
# 定義元へのリンク（行番号が分かれば #L 付き）。repo/srcpath が無ければ何も出さない
function srclink(name,   u) {
  if (repo == "" || srcpath == "") return ""
  u = repo "/blob/main/" srcpath
  if (name in srcline)
    return " <a class=\"src\" href=\"" esc(u) "#L" srcline[name] "\">" esc(srcpath) ":" srcline[name] " \342\206\227</a>"
  return " <a class=\"src\" href=\"" esc(u) "\">" esc(srcpath) " \342\206\227</a>"
}
function cells_of(row, arr,   s, n, i) {
  s = row
  sub(/^\|/, "", s)
  sub(/\|[[:space:]]*$/, "", s)
  n = split(s, arr, "|")
  for (i = 1; i <= n; i++) { sub(/^[[:space:]]+/, "", arr[i]); sub(/[[:space:]]+$/, "", arr[i]) }
  return n
}
function flush_li() {
  if (li_open) { print "<li>" inline(li_buf) "</li>"; li_open = 0; li_buf = "" }
}
function close_list() {
  if (in_list) { flush_li(); print "</ul>"; in_list = 0 }
}
function close_para() {
  if (in_para) {
    print "</p>"
    in_para = 0
    # 結論段落の続き（@brief の2文目以降）を閉じた所で注記を出す
    if (sum_tail) { sum_tail = 0; flush_notes() }
  }
}
# モジュールの注記（注記未整備・非表示件数）を結論の直後に1度だけ吐く
function flush_notes() {
  if (pend_notes != "") { printf "%s", pend_notes; pend_notes = "" }
}
# 本文が段落以外（見出し・箇条書き・コード）で始まったときの保険。結論段落を欠いたまま
# 出すと構成検査（scripts/check-docs-structure.sh）に落ちるため、未整備である旨を1文で置く。
function ensure_answer() {
  if (want_sum != 2) return
  want_sum = 0
  print "<p class=\"sum answer\">1行説明が未整備（ソースに @brief を書く）。</p>"
  flush_notes()
}
function close_table(   i, j, nc, sep, hdr, start, c1, c2) {
  if (!in_table) return
  hdr = 0
  if (tn >= 2) {
    nc = cells_of(trows[2], c2); sep = 1
    for (i = 1; i <= nc; i++) if (c2[i] !~ /^:?-+:?$/) sep = 0
    if (sep) hdr = 1
  }
  print "<div class=\"tablewrap\"><table>"
  if (hdr) {
    nc = cells_of(trows[1], c1)
    print "<thead><tr>"
    for (i = 1; i <= nc; i++) print "<th>" inline(c1[i]) "</th>"
    print "</tr></thead>"
    start = 3
  } else start = 1
  print "<tbody>"
  for (j = start; j <= tn; j++) {
    nc = cells_of(trows[j], c1)
    print "<tr>"
    for (i = 1; i <= nc; i++) print "<td>" inline(c1[i]) "</td>"
    print "</tr>"
  }
  print "</tbody></table></div>"
  tn = 0; in_table = 0
}
function close_all() { close_para(); close_list(); close_table() }
# 関数カード（article.fn）を閉じる
function close_fn() { if (fn_open) { print "</article>"; fn_open = 0 } }
BEGIN {
  if (hshift == "") hshift = 1
  in_code = 0; in_list = 0; in_para = 0; in_table = 0; li_open = 0; tn = 0; first = 1
  fn_open = 0; skipsec = 0
  # 最初の段落はモジュールの1行説明（@brief）。関数見出しの直後も同じ扱いにする。
  # 2＝モジュールの結論（見出し直後に置く p.sum.answer）、1＝関数カードの1行説明（p.sum）。
  # 索引の描画（inline_only）は段落を組まないので結論を求めない（0）
  want_sum = inline_only ? 0 : 2
  sum_tail = 0
  pend_notes = ENVIRON["MOD_NOTES"]
  if (linemap != "") {
    while ((getline rec < linemap) > 0) {
      mi = index(rec, "\t")
      if (mi > 0) srcline[substr(rec, 1, mi - 1)] = substr(rec, mi + 1)
    }
    close(linemap)
  }
}
{
  line = $0
  # 索引（目次）用: 生HTML <TAB> markdown <TAB> 生HTML を組み立てる
  if (inline_only) {
    mi = index(line, "\t")
    if (mi == 0) { print line; next }
    rec = substr(line, mi + 1)
    mj = index(rec, "\t")
    if (mj == 0) { print substr(line, 1, mi - 1) inline(rec); next }
    print substr(line, 1, mi - 1) inline(substr(rec, 1, mj - 1)) substr(rec, mj + 1)
    next
  }
  # 落とす節（shdoc の Index）は次の見出しまで読み飛ばす
  if (skipsec) {
    if (line ~ /^#{1,6} /) skipsec = 0
    else next
  }
  if (in_code) {
    if (line ~ /^```/) { print "<pre><code" code_cls ">" code_buf "</code></pre>"; in_code = 0 }
    else code_buf = (code_buf == "") ? esc(line) : code_buf "\n" esc(line)
    next
  }
  if (line ~ /^```/) {
    close_all()
    ensure_answer()
    want_sum = 0
    lang = substr(line, 4)
    sub(/[[:space:]]+$/, "", lang)
    code_cls = (lang == "") ? "" : " class=\"language-" esc(lang) "\""
    code_buf = ""
    in_code = 1
    next
  }
  if (line ~ /^#{1,6} /) {
    close_all()
    lvl = 0
    while (substr(line, lvl + 1, 1) == "#") lvl++
    text = substr(line, lvl + 2)
    sub(/^[[:space:]]+/, "", text); sub(/[[:space:]]+$/, "", text)
    # 先頭の h1（shdoc の @file 見出し）はモジュール見出しと重複するので落とす
    if (first && lvl == 1 && (slug(text) == slug(droph1) || slug(text) == slug(droph1b))) { first = 0; want_sum = 2; next }
    wasfirst = first
    first = 0
    if (lvl == 2) {
      # shdoc の Index は「説明つきの索引」をページ上部に置いたので本文からは落とす
      if (slug(text) == "index") { close_fn(); skipsec = 1; next }
      # Overview 見出しはモジュール見出しの直後で冗長。中身だけ残す（結論待ちの状態も保つ）
      if (slug(text) == "overview") { close_fn(); next }
    }
    # モジュール見出し自身の前では結論を求めない（結論はその次の段落）
    if (!(wasfirst && lvl == 1)) ensure_answer()
    want_sum = 0
    h = lvl + hshift
    if (h > 6) h = 6
    # 関数配下の詳細見出し（Arguments / Exit codes …）は関数名で修飾し、id の重複を避ける。
    # shdoc の md では h3 = 関数、h4 = 詳細、h2 = Overview/Index/@section。
    if (lvl >= 4 && cur != "") id = prefix "-" cur "-" slug(text)
    else {
      id = prefix "-" slug(text)
      cur = (lvl == 3) ? slug(text) : ""
    }
    if (id in used) { used[id]++; id = id "-" used[id] } else used[id] = 1
    if (lvl <= 3) close_fn()
    if (lvl == 3) {
      # 関数カード: 見出し（＋定義元リンク）→ 役割の1行説明（p.sum）→ 詳細
      printf "<article class=\"fn\" id=\"%s\">\n", id
      fn_open = 1
      printf "<h%d class=\"fn-h\"><a class=\"anch\" href=\"#%s\">%s</a>%s</h%d>\n", h, id, esc(text), srclink(text), h
      want_sum = 1
      next
    }
    printf "<h%d id=\"%s\"%s>%s</h%d>\n", h, id, (lvl >= 4 ? " class=\"lbl\"" : ""), inline(jp(text)), h
    next
  }
  if (line ~ /^[[:space:]]*$/) { close_all(); next }
  # @noargs の定型文（shdoc は英語の斜体で出す）は日本語の一言に置き換える
  if (line == "_Function has no arguments._") {
    close_all()
    ensure_answer()
    want_sum = 0
    print "<p class=\"noargs\">引数を取らない</p>"
    next
  }
  if (line ~ /^[*-] /) {
    close_para(); close_table()
    ensure_answer()
    want_sum = 0
    if (!in_list) { print "<ul>"; in_list = 1 }
    flush_li()
    li_buf = substr(line, 3)
    li_open = 1
    next
  }
  if (in_list && line ~ /^[[:space:]]+[^[:space:]]/) {
    t = line; sub(/^[[:space:]]+/, "", t)
    if (li_open) li_buf = li_buf " " t
    else { li_buf = t; li_open = 1 }
    next
  }
  if (line ~ /^\|/) {
    close_para(); close_list()
    ensure_answer()
    want_sum = 0
    in_table = 1
    trows[++tn] = line
    next
  }
  # 箇条書きの直後に続く非空行は、その項目の続き（Markdown の lazy continuation）。
  # shdoc は継続行のインデントを落とすため、これが無いと項目本文が段落に分断される。
  if (in_list && li_open) { li_buf = li_buf " " line; next }
  close_list(); close_table()
  if (!in_para) {
    # モジュール見出し直後の段落は「節の結論」。ピラミッド原則（結論は1文）に合わせて
    # 先頭1文だけを p.sum.answer として切り出し、残りは続く段落へ回す。
    if (want_sum == 2) {
      want_sum = 0
      hd = answer1(line)
      tail = substr(line, length(hd) + 1)
      sub(/^[[:space:]]+/, "", tail)
      print "<p class=\"sum answer\">"
      print inline(hd)
      print "</p>"
      if (tail == "") { flush_notes(); next }
      print "<p class=\"sum\">"
      in_para = 1; sum_tail = 1
      print inline(tail)
      next
    }
    # 関数見出し直後の段落は「役割の1行説明」として見出しに添える
    print (want_sum ? "<p class=\"sum\">" : "<p>")
    in_para = 1; want_sum = 0
  } else print "<br>"
  print inline(line)
}
END {
  if (in_code) print "<pre><code" code_cls ">" code_buf "</code></pre>"
  close_all()
  close_fn()
  ensure_answer()
  flush_notes()
}
MD2HTML_AWK

# ---------------------------------------------------------------------------
# 索引用メタ情報の抽出（awk）。shdoc の md から:
#   B <TAB> モジュールの1行説明
#   F <TAB> 関数名 <TAB> 説明の先頭1文（説明が無ければ空）
# 「先頭1文」は HEAD1_AWK の head1() が切り出す（括弧の外にある最初の「。」まで）。
# ---------------------------------------------------------------------------
read -r -d '' META_BODY <<'META_AWK_SRC'
# 溜めた段落を1文に切り出して吐く。関数は説明が無くても必ず1行出す（索引から消さない）
function emit() {
  if (target == "F") print "F\t" name "\t" head1(buf)
  else if (target == "B" && buf != "") print "B\t" head1(buf)
  target = ""; buf = ""; nl = 0
}
BEGIN { target = "B"; buf = ""; name = ""; nl = 0 }
/^# /   { emit(); target = "B"; next }
/^### / {
  emit()
  name = substr($0, 5)
  sub(/^[[:space:]]+/, "", name); sub(/[[:space:]]+$/, "", name)
  target = "F"
  next
}
/^#/ { emit(); next }
{
  line = $0
  gsub(/\t/, " ", line)
  sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
  # 空行・箇条書きは段落の切れ目（見出し直後の空行では確定しない＝説明はその次の行から始まる）
  if (line == "" || line ~ /^[*-] /) { if (buf != "") emit(); next }
  if (line ~ /^_Function has no/) next
  if (target == "") next
  # 1文が行またぎでも拾えるよう最大2行まで連結する（日本語の折返しは詰めて、英文は空白で継ぐ）
  if (nl >= 2) next
  if (buf == "") buf = line
  else if (substr(buf, length(buf), 1) ~ /^[ -~]$/) buf = buf " " line
  else buf = buf line
  nl++
}
END { emit() }
META_AWK_SRC

# 共通関数（head1）を各 awk プログラムの先頭に連結する（同じ切り出し規則を1か所で持つ）
MD2HTML="$HEAD1_AWK
$MD2HTML"
META_AWK="$HEAD1_AWK
$META_BODY"
SPLIT1_AWK="$HEAD1_AWK
$SPLIT1_BODY"

# @description 対象スクリプトを決定論的な順序で列挙する。
# @stdout 対象ファイルのパス（リポジトリルートからの相対、LC_ALL=C 順）
list_targets() {
  local f
  for f in scripts/*.sh mape/*.sh .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    printf '%s\n' "$f"
  done | sort
}

# @description パスやラベルからアンカー用の slug を作る。
# @arg $1 string 元の文字列
# @stdout 英小文字・数字・_ と - だけからなる slug
slugify() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9_]+/-/g; s/^-+//; s/-+$//'
}

# @description パスからアンカー ID を作る（HTML の id と目次リンクで共有する）。
# @arg $1 string 相対パス
# @stdout mod- で始まるアンカー ID
mod_id() {
  printf 'mod-%s' "$(slugify "$1")"
}

# @description モジュールを読者にとっての役割で分類する（GROUP_DEFS のキーを返す）。
# @arg $1 string 相対パス
# @stdout グループキー。どれにも当てはまらなければ other（＝「その他」に必ず出る）
group_of() {
  case "$1" in
    .claude/hooks/*)      printf 'hook' ;;
    scripts/test-*)       printf 'test' ;;
    mape/tests/*)         printf 'test' ;;
    scripts/check.sh|scripts/check-*|scripts/validate-*) printf 'gate' ;;
    scripts/build-*)      printf 'tool' ;;
    mape/*)               printf 'mape' ;;
    *)                    printf 'other' ;;
  esac
}

# @description shdoc 注記が無いファイル向けのフォールバック。先頭のコメントブロックを説明として使う。
# @arg $1 string 対象ファイル
# @stdout Markdown（段落のみ）
fallback_md() {
  "$GAWK" 'NR == 1 && /^#!/ { next }
           /^#/ { sub(/^#[[:space:]]?/, "", $0); print; next }
           { exit }' "$1"
}

# @description 関数名 → 定義行番号の対応表を作る（定義元リンクの #L に使う）。
# @arg $1 string 対象ファイル
# @stdout `関数名 <TAB> 行番号` の行（同名は最初の定義を採る）
line_map() {
  "$GAWK" '{
    s = $0
    sub(/^[[:space:]]+/, "", s)
    sub(/^function[[:space:]]+/, "", s)
    if (s ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/) {
      sub(/[[:space:]]*\(\).*$/, "", s)
      if (!(s in seen)) { seen[s] = 1; print s "\t" NR }
    }
  }' "$1"
}

# @description ファイル中の @internal 注記（＝非公開ヘルパー）の件数を数える。
# @arg $1 string 対象ファイル
# @stdout 件数（0 以上の整数）
internal_count() {
  grep -c '^[[:space:]]*#[[:space:]]*@internal' "$1" 2>/dev/null || true
}

esc_html() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

work=$(mktemp -d) || { echo "error: 作業ディレクトリを作れない" >&2; exit 1; }
trap 'rm -rf "$work"' EXIT

# --- 各モジュールの Markdown・メタ情報を作る ---------------------------------
n=0
internal_total=0
: > "$work/paths"
: > "$work/manifest"
while IFS= read -r f; do
  n=$((n + 1))
  if ! "$GAWK" -E "$SHDOC" < "$f" > "$work/$n.md"; then
    echo "error: shdoc の実行に失敗: $f" >&2
    exit 1
  fi
  # shdoc は注記が1つも無いファイルにも空行だけを吐くため、空白のみは「出力なし」とみなす
  if grep -q '[^[:space:]]' "$work/$n.md"; then
    : > "$work/$n.fallback"
  else
    # 注記が未整備でも目次からモジュールが消えないようにする（注記が入れば shdoc の出力が勝つ）
    fallback_md "$f" > "$work/$n.md"
    printf 'yes' > "$work/$n.fallback"
  fi
  "$GAWK" "$META_AWK" "$work/$n.md" > "$work/$n.meta"
  line_map "$f" > "$work/$n.lines"
  ic=$(internal_count "$f")
  printf '%s' "$ic" > "$work/$n.internal"
  internal_total=$((internal_total + ic))
  printf '%s\n' "$f" >> "$work/paths"
  printf '%s\t%s\t%s\n' "$(group_of "$f")" "$n" "$f" >> "$work/manifest"
done < <(list_targets)

if [ "$n" -eq 0 ]; then
  echo "error: 文書化対象のスクリプトが1つも見つからない（scripts/*.sh, mape/*.sh, .claude/hooks/*.sh）" >&2
  exit 1
fi

funcs=$(cat "$work"/*.md | grep -c '^### ' || true)

# --- グループ順に並べ直す（未分類が落ちていないことを検証する） ---------------
printf '%s\n' "$GROUP_DEFS" > "$work/groups"

# @description GROUP_DEFS の1行を key / 見出し / 説明に分解して大域変数へ入れる。
# @arg $1 string `key|見出し|説明` の1行
# @set g_key string グループキー
# @set g_title string グループ見出し
# @set g_desc string グループの1行説明
split_group() {
  local rest
  g_key=${1%%|*}
  rest=${1#*|}
  g_title=${rest%%|*}
  g_desc=${rest#*|}
}

# @description 説明文を「結論の1文」と「残り」に割る（ピラミッド原則: 見出しの直後は1文の結論）。
# @arg $1 string 説明文（1行）
# @set s_head string 先頭1文（結論。句点が無ければ全体）
# @set s_rest string 2文目以降（無ければ空）
split_sentence() {
  local out
  out=$(printf '%s\n' "$1" | "$GAWK" "$SPLIT1_AWK")
  s_head=${out%%$'\t'*}
  s_rest=${out#*$'\t'}
}

: > "$work/ordered"
while IFS= read -r grow; do
  [ -n "$grow" ] || continue
  split_group "$grow"
  "$GAWK" -F '\t' -v k="$g_key" '$1 == k' "$work/manifest" >> "$work/ordered"
done < "$work/groups"

ordered_n=$(grep -c '' "$work/ordered" || true)
if [ "$ordered_n" -ne "$n" ]; then
  echo "error: グループ分けでモジュールが欠落した（対象 $n 件 / 分類できたもの $ordered_n 件）" >&2
  echo "       scripts/build-docs.sh の GROUP_DEFS と group_of を確認せよ" >&2
  exit 1
fi

# --- 索引（グループ → モジュール → 関数）を組み立てる ------------------------
# 1行 = 「生HTML <TAB> markdown <TAB> 生HTML」。markdown 部分だけを MD2HTML の
# inline_only で描画する（説明中の `code` や **強調** を索引でも同じ見た目にする）。
toc="$work/toc.tsv"
: > "$toc"
{
  echo '<nav class="toc" id="toc" aria-label="関数索引">'
  echo '<div class="find" id="find" hidden>'
  echo '<label for="q">索引を絞り込む</label>'
  echo '<input id="q" type="search" autocomplete="off" spellcheck="false" placeholder="関数名・説明で絞り込む（例: push / 判定 / quarantine）">'
  echo '<span class="qn" id="qn" role="status" aria-live="polite"></span>'
  echo '</div>'
  while IFS= read -r grow; do
    [ -n "$grow" ] || continue
    split_group "$grow"
    mods=$("$GAWK" -F '\t' -v k="$g_key" '$1 == k { print $2 "\t" $3 }' "$work/manifest")
    [ -n "$mods" ] || continue
    split_sentence "$g_desc"
    printf '<section class="grp" id="grp-%s">\n' "$g_key"
    printf '<h2 class="ghead"><a href="#g-%s">%s</a></h2>\n' "$g_key" "$(esc_html "$g_title")"
    # 見出しの直後は1文の結論（p.answer）。2文目以降は続く段落に回す（.claude/rules/docs.md）
    printf '<p class="gd answer">\t%s\t</p>\n' "$s_head"
    if [ -n "$s_rest" ]; then
      printf '<p class="gd">\t%s\t</p>\n' "$s_rest"
    fi
    echo '<ul class="mods">'
    while IFS=$'\t' read -r idx path; do
      [ -n "$idx" ] || continue
      id=$(mod_id "$path")
      brief=$("$GAWK" -F '\t' '$1 == "B" { print $2; exit }' "$work/$idx.meta")
      nfn=$(grep -c '^### ' "$work/$idx.md" || true)
      printf '<li class="mod-item">\n'
      printf '<div class="mod-line"><a href="#%s">%s</a> <span class="d">\t%s\t</span></div>\n' \
        "$id" "$(esc_html "$path")" "$brief"
      if [ "$nfn" -gt 0 ]; then
        if [ "$nfn" -gt "$FN_FOLD" ]; then
          printf '<details class="fns">\n'
        else
          printf '<details class="fns" open>\n'
        fi
        printf '<summary>関数 %s 件</summary>\n' "$nfn"
        echo '<ul>'
        while IFS=$'\t' read -r _kind fname fsum; do
          printf '<li class="fn-item"><a href="#%s-%s"><code>%s</code></a> <span class="d">\t%s\t</span></li>\n' \
            "$id" "$(slugify "$fname")" "$(esc_html "$fname")" "$fsum"
        done < <("$GAWK" -F '\t' '$1 == "F"' "$work/$idx.meta")
        echo '</ul>'
        echo '</details>'
      fi
      echo '</li>'
    done <<MODS_EOF
$mods
MODS_EOF
    echo '</ul>'
    echo '</section>'
  done < "$work/groups"
  echo '</nav>'
} > "$toc"

# --- HTML を組み立てる -------------------------------------------------------
gen="$work/out.html"
{
  cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ソースリファレンス — Scoria</title>
<meta name="description" content="Scoria の開発基盤スクリプト（scripts / mape / .claude/hooks）のリファレンス。役割別の索引・1行説明・検索つき。ソースのコメントから自動生成。">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Crect width='24' height='24' fill='%230a0a0a'/%3E%3Ctext x='12' y='17' font-size='15' font-family='monospace' font-weight='800' fill='%23fff' text-anchor='middle'%3Ed%3C/text%3E%3C/svg%3E">
<script>
  /* 描画前にテーマを確定して切替時のちらつきを防ぐ（保存があればそれを優先。無ければ OS 設定に従う） */
  (function () {
    try {
      var t = localStorage.getItem('scoria-docs-theme');
      if (t === 'light' || t === 'dark') { document.documentElement.setAttribute('data-theme', t); }
    } catch (e) {}
  })();
</script>
<style>
:root{--bg:#ffffff;--bg-soft:#fafafa;--panel:#ffffff;--line:#eaeaea;--line-strong:#d4d4d4;
  --fg:#0a0a0a;--fg-soft:#555555;--fg-mute:#8a8a8a;--inv:#ffffff;--maxw:1080px;
  --font:-apple-system,BlinkMacSystemFont,"Segoe UI","Hiragino Kaku Gothic ProN","Hiragino Sans",Meiryo,sans-serif;
  --mono:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,monospace}
@media (prefers-color-scheme:dark){:root{--bg:#000000;--bg-soft:#0a0a0a;--panel:#0c0c0c;--line:#1e1e1e;--line-strong:#333333;--fg:#ededed;--fg-soft:#a1a1a1;--fg-mute:#707070;--inv:#000000}}
:root[data-theme="light"]{--bg:#ffffff;--bg-soft:#fafafa;--panel:#ffffff;--line:#eaeaea;--line-strong:#d4d4d4;--fg:#0a0a0a;--fg-soft:#555555;--fg-mute:#8a8a8a;--inv:#ffffff}
:root[data-theme="dark"]{--bg:#000000;--bg-soft:#0a0a0a;--panel:#0c0c0c;--line:#1e1e1e;--line-strong:#333333;--fg:#ededed;--fg-soft:#a1a1a1;--fg-mute:#707070;--inv:#000000}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);font-family:var(--font);font-size:15px;line-height:1.7;-webkit-font-smoothing:antialiased;letter-spacing:-.003em}
a{color:inherit}
.wrap{max-width:var(--maxw);margin:0 auto;padding:0 24px}
@media (max-width:600px){.wrap{padding:0 16px}}

/* ---------- Header ---------- */
header{position:sticky;top:0;z-index:40;background:var(--bg);border-bottom:1px solid var(--line)}
@supports (backdrop-filter:blur(8px)){header{background:color-mix(in srgb,var(--bg) 82%,transparent);backdrop-filter:blur(8px)}}
.nav{display:flex;align-items:center;height:56px;gap:24px}
.brand{display:flex;align-items:center;gap:9px;font-weight:700;letter-spacing:-.02em;font-size:16px;text-decoration:none}
.mark{width:22px;height:22px;border:1.5px solid var(--fg);display:grid;place-items:center;font-family:var(--mono);font-size:12px;font-weight:800}
.links{margin-left:auto;display:flex;align-items:center;gap:2px}
.links a{text-decoration:none;color:var(--fg-soft);font-size:13.5px;padding:6px 11px;transition:color .12s}
.links a:hover{color:var(--fg)}
.links a[aria-current="page"]{color:var(--fg);font-weight:650}
.links a.gh{border:1px solid var(--line-strong);color:var(--fg);margin-left:6px}
.links a.gh:hover{background:var(--fg);color:var(--inv)}
.tt{margin-left:4px;width:30px;height:30px;border:1px solid var(--line-strong);background:transparent;color:var(--fg-soft);cursor:pointer;font-size:13px;display:grid;place-items:center;font-family:var(--font)}
.tt:hover{color:var(--fg)}
.tt svg{width:15px;height:15px;display:block}
@media (max-width:760px){.links a.hide-sm{display:none}.links a{padding:6px 7px;font-size:12.5px}.links a.gh{margin-left:4px}.nav{gap:12px}}
@media (max-width:460px){.links a.hide-xs{display:none}}

/* ---------- Page head ---------- */
.phead{border-bottom:1px solid var(--line);padding:44px 0 34px}
.kicker{display:inline-flex;align-items:center;gap:8px;font-family:var(--mono);font-size:12px;letter-spacing:.04em;color:var(--fg-soft);border:1px solid var(--line-strong);padding:4px 10px}
.kicker b{color:var(--fg);font-weight:700}
h1{font-size:clamp(26px,4vw,38px);line-height:1.15;margin:20px 0 0;font-weight:800;letter-spacing:-.035em}
.lead{margin:16px 0 0;font-size:16px;color:var(--fg-soft);max-width:46em;line-height:1.65}
.crumbs{display:flex;flex-wrap:wrap;gap:8px;margin-top:22px;font-family:var(--mono);font-size:12.5px;color:var(--fg-mute)}
.crumbs a{color:var(--fg-soft);text-decoration:none;border-bottom:1px solid var(--line-strong)}
.crumbs a:hover{color:var(--fg)}
.stats{display:flex;flex-wrap:wrap;margin-top:28px;border-top:1px solid var(--line);border-left:1px solid var(--line)}
.stat{flex:1 1 150px;border-right:1px solid var(--line);border-bottom:1px solid var(--line);padding:13px 17px}
.stat b{display:block;font-family:var(--mono);font-size:18px;font-weight:800;letter-spacing:-.02em}
.stat span{font-size:11.5px;color:var(--fg-mute)}

/* 本文の折り返し。注釈には MAPE_HEALTH/MAPE_POLICY/MAPE_BACKLOG/... のような空白を含まない
   長い連結トークンが現れうる。個別クラスにだけ overflow-wrap を当てると取りこぼして
   狭い画面で本文がはみ出す（実測: 390px 幅で文書全体が 515px に膨らんでいた）ため、
   散文要素にまとめて当てる。code/pre 側は別途 overflow-x で扱う。 */
p, li, dd, dt, td, th, figcaption{overflow-wrap:anywhere}

/* 用語の初出。点線下線＋ホバーで1行の意味が出る */
abbr[title]{text-decoration:none;-webkit-text-decoration:none;border-bottom:1px dotted var(--line-strong);
  cursor:help;font-weight:700;color:var(--fg)}
abbr[title]:hover{border-bottom-color:var(--fg)}

/* ---------- 読み方 ---------- */
.howto{border:1px solid var(--line);border-left:2px solid var(--fg);background:var(--bg-soft);padding:16px 20px;margin:32px 0 8px}
.howto b{display:block;font-family:var(--mono);font-size:13px;letter-spacing:.03em;margin-bottom:6px}
.howto ul{margin:0;padding-left:20px;color:var(--fg-soft);font-size:13.5px}
.howto li{margin:4px 0}
.howto code{overflow-wrap:anywhere}

/* ---------- 索引 ---------- */
.toc{margin:32px 0 8px}
.find{display:flex;align-items:center;gap:10px;flex-wrap:wrap;border:1px solid var(--line);background:var(--bg-soft);padding:12px 16px;margin-bottom:28px}
.find label{font-size:12.5px;color:var(--fg-mute);font-family:var(--mono)}
.find input{flex:1 1 260px;min-width:0;background:var(--bg);color:var(--fg);border:1px solid var(--line-strong);padding:7px 10px;font-family:var(--font);font-size:14px}
.find input:focus{outline:1px solid var(--fg);outline-offset:-1px}
.find .qn{font-family:var(--mono);font-size:12px;color:var(--fg-mute)}
.grp{margin:0 0 30px}
.ghead{font-size:16px;font-weight:800;letter-spacing:-.02em;margin:0;padding-top:14px;border-top:1px solid var(--line)}
.ghead a{text-decoration:none}
.grp .gd{margin:4px 0 10px;font-size:13px;color:var(--fg-soft);max-width:60em}
.mods{list-style:none;margin:0;padding:0}
.mod-item{border-top:1px solid var(--line);padding:9px 0}
.mod-line{display:flex;flex-wrap:wrap;gap:4px 10px;align-items:baseline}
.mod-line a{font-family:var(--mono);font-size:13.5px;font-weight:700;text-decoration:none;border-bottom:1px solid var(--line-strong);overflow-wrap:anywhere}
.mod-line a:hover{border-bottom-color:var(--fg)}
.d{color:var(--fg-soft);font-size:12.8px;min-width:0;overflow-wrap:anywhere}
.fns{margin:6px 0 0}
.fns summary{cursor:pointer;font-family:var(--mono);font-size:12px;color:var(--fg-mute);list-style:none;display:inline-block;border:1px solid var(--line);padding:1px 8px}
.fns summary::-webkit-details-marker{display:none}
.fns summary::before{content:"▸ "}
.fns[open]>summary::before{content:"▾ "}
.fns summary:hover{color:var(--fg)}
.fns ul{list-style:none;margin:6px 0 2px;padding:0 0 0 14px;border-left:1px solid var(--line)}
.fn-item{display:flex;flex-wrap:wrap;gap:2px 10px;align-items:baseline;padding:2px 0}
.fn-item a{text-decoration:none}
.fn-item code{font-family:var(--mono);font-size:12.5px;background:none;border:0;padding:0;border-bottom:1px solid var(--line-strong)}
.fn-item a:hover code{border-bottom-color:var(--fg)}

/* ---------- 本文 ---------- */
.body{padding:8px 0 96px}
.body h2.g{font-size:clamp(19px,3vw,24px);font-weight:800;letter-spacing:-.03em;margin:64px 0 4px;padding-top:26px;border-top:2px solid var(--fg);scroll-margin-top:70px}
.body p.g{margin:0 0 8px;color:var(--fg-soft);font-size:13.5px;max-width:60em}
.mod{scroll-margin-top:70px;border-top:1px solid var(--line);padding:22px 0 8px;margin-top:22px}
.mod-h{font-size:16px;margin:0 0 6px;font-family:var(--mono);letter-spacing:-.01em;display:flex;flex-wrap:wrap;gap:6px 12px;align-items:baseline}
.mod-h .mp{overflow-wrap:anywhere}
.mod>p{margin:8px 0;color:var(--fg-soft);max-width:62em}
.mod>p.sum{color:var(--fg)}
.mod>ul{margin:8px 0;padding-left:20px;color:var(--fg-soft);max-width:62em}
.src{font-family:var(--mono);font-size:11.5px;font-weight:400;color:var(--fg-mute);text-decoration:none;border-bottom:1px solid var(--line);white-space:nowrap}
.src:hover{color:var(--fg);border-bottom-color:var(--line-strong)}
/* 極端に狭い画面では定義元リンクも折り返す（本文を横スクロールさせない） */
@media (max-width:420px){.src{white-space:normal;overflow-wrap:anywhere}}
.note{color:var(--fg-mute);font-size:12.5px;margin:6px 0}
.fn{border:1px solid var(--line);background:var(--panel);padding:14px 18px;margin:14px 0;scroll-margin-top:70px}
.fn-h{font-size:15px;margin:0;font-family:var(--mono);letter-spacing:-.01em;display:flex;flex-wrap:wrap;gap:4px 12px;align-items:baseline}
.fn-h .anch{text-decoration:none;font-weight:700;overflow-wrap:anywhere}
.fn-h .anch:hover{border-bottom:1px solid var(--fg)}
.fn p{margin:6px 0;color:var(--fg-soft);max-width:62em}
.fn p.sum{color:var(--fg);margin:4px 0 8px}
.fn p.noargs{font-size:12.5px;color:var(--fg-mute)}
.fn h5{font-size:11.5px;font-family:var(--mono);letter-spacing:.05em;color:var(--fg-mute);font-weight:600;margin:12px 0 2px;text-transform:none}
.fn h5+ul{list-style:none;margin:0;padding:0;border-left:1px solid var(--line)}
.fn h5+ul li{padding:2px 0 2px 12px;font-size:13.5px;color:var(--fg-soft)}
.fn h5+ul li strong{color:var(--fg);font-family:var(--mono);font-weight:700}
ul{margin:8px 0;padding-left:20px}
li{margin:3px 0}
code{font-family:var(--mono);font-size:.9em;background:var(--bg-soft);border:1px solid var(--line);padding:1px 4px;overflow-wrap:anywhere}
pre{background:var(--bg-soft);border:1px solid var(--line);padding:12px;overflow-x:auto;margin:8px 0;font-family:var(--mono);font-size:12.6px;line-height:1.8}
pre code{border:0;background:none;padding:0}
.tablewrap{overflow-x:auto;border:1px solid var(--line);margin:10px 0}
table{border-collapse:collapse;width:100%;font-size:13.5px}
th,td{text-align:left;padding:7px 12px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-size:11.5px;font-family:var(--mono);color:var(--fg-mute);background:var(--bg-soft);white-space:nowrap}
tr:last-child td{border-bottom:0}

/* ---------- Footer ---------- */
footer{border-top:1px solid var(--line);padding:30px 0}
.foot{display:flex;flex-wrap:wrap;gap:12px;justify-content:space-between;align-items:center;font-family:var(--mono);font-size:12.5px;color:var(--fg-mute)}
.foot a{color:var(--fg-soft);text-decoration:none}
.foot a:hover{color:var(--fg)}
.top-link{position:fixed;right:20px;bottom:20px;width:38px;height:38px;border:1px solid var(--line-strong);background:var(--bg);display:grid;place-items:center;text-decoration:none;color:var(--fg-soft);font-size:14px;z-index:20}
.top-link:hover{color:var(--fg);border-color:var(--fg)}
@media (max-width:1000px){.top-link{display:none}}
[hidden]{display:none !important}
</style>
</head>
<body>

<header>
  <div class="wrap nav">
    <a class="brand" href="reference.html"><span class="mark">s</span> Scoria</a>
    <nav class="links">
      <a href="reference.html" aria-current="page">ソースリファレンス</a>
      <a class="gh" href="https://github.com/nigoh/scoria">GitHub ↗</a>
      <button class="tt" id="tt" aria-label="テーマ切替" title="テーマ切替">
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8.5" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 3.5a8.5 8.5 0 000 17z" fill="currentColor"/></svg>
      </button>
    </nav>
  </div>
</header>

<main id="top">

<section class="phead">
  <div class="wrap">
    <span class="kicker"><b>ソースリファレンス</b> — スクリプトを直接触る人へ</span>
    <h1>この関数は何をして、どこで止まるのか。</h1>
    <p class="answer lead">Scoria の開発基盤スクリプト（<code>scripts/</code> / <code>mape/</code> / <code>.claude/hooks/</code>）を、役割ごとに並べたリファレンスです。</p>
    <p class="lead">索引には各関数の1行説明が付いています。目的の関数は検索で絞り込めます。これらのスクリプトは土台リポジトリ <abbr title="Dev environment base。Claude Code で開発するときの進め方とルールを一式そろえた土台リポジトリ">deb</abbr> から移植したものです。</p>
    <div class="crumbs">
      <span>関連:</span>
      <a href="../CLAUDE.md">CLAUDE.md</a><span>·</span><a href="adr/README.md">意思決定記録</a><span>·</span><a href="process/README.md">開発プロセス</a>
    </div>
HTML_HEAD

  # 実測値（すべて入力から決まる。日時・ホスト名・絶対パスは混ぜない）
  ngroups=$("$GAWK" -F '\t' '{ g[$1] = 1 } END { print length(g) }' "$work/manifest")
  printf '    <div class="stats">\n'
  printf '      <div class="stat"><b>%s</b><span>モジュール</span></div>\n' "$n"
  printf '      <div class="stat"><b>%s</b><span>公開関数</span></div>\n' "$funcs"
  printf '      <div class="stat"><b>%s</b><span>役割グループ</span></div>\n' "$ngroups"
  printf '      <div class="stat"><b>%s</b><span>@internal（非公開・非表示）</span></div>\n' "$internal_total"
  printf '    </div>\n'
  cat <<HTML_HOWTO
  </div>
</section>

<div class="wrap">

<section class="howto">
  <b>このページの読み方</b>
  <ul>
    <li><strong>載っているもの</strong>: 各スクリプトのファイル説明と、<abbr title="シェルスクリプトのコメントから API リファレンスを生成するツール（MIT）">shdoc</abbr> 注記が付いた<strong>公開関数</strong>（$funcs 件）。引数・終了コード・出力・使用例が関数ごとに並びます。</li>
    <li><strong>載っていないもの</strong>: <code>@internal</code> を付けた内部ヘルパー（$internal_total 件）。実装の詳細なので索引を汚さないよう伏せています。読むならソース本体へ。</li>
    <li><strong>探し方</strong>: 索引は<strong>役割ごと</strong>（<abbr title="作業を終える前に必ず通す検査の集合。入口は scripts/check.sh の1つだけ">品質ゲート</abbr> / <abbr title="Claude Code がツールを実行する直前などに自動で走る小さなスクリプト">フック</abbr> / <abbr title="夜間に自分を点検して改善案を出す仕組み。Monitor→Analyze→Plan→Execute と共有知識 Knowledge">MAPE-K</abbr> / ツール / テスト）に並んでいます。関数名でも説明文でも絞り込めます。関数見出しの右のリンクは GitHub 上の定義行へ飛びます。</li>
    <li><strong>何を守るコードか</strong>: ここに並ぶのは、<abbr title="Claude Code への指示書を「いつ読ませたいか」で置き分ける仕組み">steering</abbr> に書いた規約を実際に効かせる<abbr title="ルールを実際に効かせる仕掛けのこと（文書・フック・CI など）">機構</abbr>の本体です。<abbr title="Claude がターンを終えようとした時に走るフック。品質ゲートが赤なら終了を止める">Stop フック</abbr>が作業の終了を止め、<abbr title="要件・設計・テストを ID で結び、どのテストがどの要件を守るかを追えるようにすること">トレーサビリティ</abbr>検査が要件とテストの結び付きを確かめ、決定は <abbr title="Architecture Decision Record。決定を1件1枚・連番で残す記録。結論だけでなく選ばなかった案と理由も書く">ADR</abbr> に残させます。</li>
    <li><strong>安全側に倒す</strong>: 判定に必要な情報が欠けたときは <abbr title="判断に必要な情報が欠けたとき、許可ではなく停止の側に倒す設計">fail-closed</abbr>（許可ではなく停止）に倒します。夜間の自動改善は <abbr title="失敗が続いたときに自動処理を止める安全装置">サーキットブレーカー</abbr>と <abbr title="自動処理を進めてよい安全な状態かどうかの判定。危険なら実行を抑止する">safe-state</abbr> 判定で止まり、成果は<abbr title="まだレビュー前の下書き状態の Pull Request。自動化された経路はここまでしか進まない">ドラフト PR</abbr> までしか進みません。</li>
    <li><strong>正本はソース</strong>: このページは <code>bash scripts/build-docs.sh</code> がソースのコメントから生成します（手で編集しない）。ソースとの乖離は <code>bash scripts/build-docs.sh --check</code> が CI で検出します。</li>
  </ul>
</section>
HTML_HOWTO

  # 索引（グループ → モジュール → 関数。説明の先頭1文つき）
  "$GAWK" -v inline_only=1 "$MD2HTML" "$toc"

  # 本体
  echo '<div class="body">'
  prev_group=""
  while IFS=$'\t' read -r gkey idx f; do
    [ -n "$gkey" ] || continue
    if [ "$gkey" != "$prev_group" ]; then
      split_group "$(grep "^$gkey|" "$work/groups")"
      split_sentence "$g_desc"
      printf '<h2 class="g" id="g-%s">%s</h2>\n' "$g_key" "$(esc_html "$g_title")"
      printf '<p class="g answer">%s</p>\n' "$(esc_html "$s_head")"
      if [ -n "$s_rest" ]; then
        printf '<p class="g">%s</p>\n' "$(esc_html "$s_rest")"
      fi
      prev_group="$gkey"
    fi
    id=$(mod_id "$f")
    ic=$(cat "$work/$idx.internal")
    # 注記は結論段落のあとに差し込む（見出しの直後は必ず結論。MD2HTML が MOD_NOTES を吐く）
    notes=""
    if [ -s "$work/$idx.fallback" ]; then
      notes='<p class="note">（shdoc 注記が未整備のため、先頭のコメントブロックから生成）</p>'$'\n'
    fi
    if [ "$ic" -gt 0 ]; then
      notes="$notes$(printf '<p class="note">内部ヘルパー %s 件は非表示（<code>@internal</code>）。実装はソースを参照。</p>' "$ic")"$'\n'
    fi
    printf '<section class="mod" id="%s">\n' "$id"
    printf '<h3 class="mod-h"><span class="mp">%s</span><a class="src" href="%s/blob/main/%s">GitHub ↗</a></h3>\n' \
      "$(esc_html "$f")" "$REPO" "$f"
    MOD_NOTES="$notes" \
    "$GAWK" -v prefix="$id" -v hshift=1 -v droph1="${f##*/}" -v droph1b="$f" \
            -v repo="$REPO" -v srcpath="$f" -v linemap="$work/$idx.lines" \
            "$MD2HTML" "$work/$idx.md"
    echo '</section>'
  done < "$work/ordered"
  echo '</div>'

  cat <<'HTML_FOOT'
</div>
</main>

<footer>
  <div class="wrap foot">
    <span>MIT License · <a href="https://github.com/nigoh/scoria">nigoh/scoria</a> · 土台は <a href="https://github.com/nigoh/deb">nigoh/deb</a></span>
    <span><a href="https://github.com/nigoh/scoria">github.com/nigoh/scoria ↗</a></span>
  </div>
</footer>

<a class="top-link" href="#top" aria-label="先頭へ戻る" title="先頭へ戻る">↑</a>

<script>
  (function () {
    /* テーマ切替（OS 設定に追従しつつ、手動選択は localStorage に保存する） */
    var b = document.getElementById('tt');
    if (b) {
      b.addEventListener('click', function () {
        var r = document.documentElement;
        var cur = r.getAttribute('data-theme');
        if (!cur) { cur = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'; }
        var next = cur === 'dark' ? 'light' : 'dark';
        r.setAttribute('data-theme', next);
        try { localStorage.setItem('scoria-docs-theme', next); } catch (e) {}
      });
    }

    /* 索引の絞り込み（依存ゼロ。JS が無い環境では検索欄自体を出さず、索引は全件見える） */
    var q = document.getElementById('q');
    var find = document.getElementById('find');
    var toc = document.getElementById('toc');
    var out = document.getElementById('qn');
    if (!q || !find || !toc) { return; }
    find.hidden = false;

    var mods = [].slice.call(toc.querySelectorAll('.mod-item')).map(function (m) {
      var det = m.querySelector('details');
      var head = m.querySelector('.mod-line');
      return {
        el: m,
        det: det,
        wasOpen: det ? det.open : false,
        text: (head ? head.textContent : m.textContent).toLowerCase(),
        fns: [].slice.call(m.querySelectorAll('.fn-item')).map(function (li) {
          return { el: li, text: li.textContent.toLowerCase() };
        })
      };
    });
    var groups = [].slice.call(toc.querySelectorAll('.grp'));
    var total = mods.reduce(function (a, m) { return a + m.fns.length; }, 0);

    function every(terms, text) {
      for (var i = 0; i < terms.length; i++) { if (text.indexOf(terms[i]) < 0) { return false; } }
      return true;
    }

    function apply() {
      var terms = q.value.toLowerCase().split(/\s+/).filter(function (t) { return t.length > 0; });
      var hit = 0;
      mods.forEach(function (m) {
        var modHit = terms.length > 0 && every(terms, m.text);
        var shown = 0;
        m.fns.forEach(function (f) {
          var v = terms.length === 0 || modHit || every(terms, f.text);
          f.el.hidden = !v;
          if (v) { shown++; }
        });
        hit += shown;
        var vis = terms.length === 0 || modHit || shown > 0;
        m.el.hidden = !vis;
        /* 絞り込み中は一致した関数が見えるよう畳みを開き、クリアしたら元の状態へ戻す */
        if (m.det) { m.det.open = terms.length > 0 ? (vis && shown > 0) : m.wasOpen; }
      });
      groups.forEach(function (g) {
        var any = [].slice.call(g.querySelectorAll('.mod-item')).some(function (e) { return !e.hidden; });
        g.hidden = !any;
      });
      if (out) { out.textContent = terms.length > 0 ? ('一致 ' + hit + ' / ' + total + ' 件') : ''; }
    }

    q.addEventListener('input', apply);
    q.addEventListener('search', apply);
    apply();
  })();
</script>
</body>
</html>
HTML_FOOT
} > "$gen"

# --- 後処理: 解決できないページ内リンクを素のテキストに落とす ----------------
# shdoc の `@see [x](#x)` は、モジュール接頭辞を付けた id に解決できないことがある
# （実際に mape/lib.sh の @see 由来で 3 件のリンク切れが出ていた）。飛び先の無いリンクを
# 残すより、リンクを外して文字として見せるほうが読者に誠実なので、生成の最後に落とす。
# 個別の注釈を直すのではなく生成器側で吸収するのは、同じ書き方が再び現れても壊れないため。
"$GAWK" '
  # 1周目: ページ内に存在する id を集める
  NR == FNR {
    s = $0
    while (match(s, /id="[^"]*"/)) {
      ids[substr(s, RSTART + 4, RLENGTH - 5)] = 1
      s = substr(s, RSTART + RLENGTH)
    }
    next
  }
  # 2周目: 飛び先の無い <a href="#..."> を中身のテキストで置き換える
  {
    out = ""; rest = $0
    while (match(rest, /<a href="#[^"]*">[^<]*<\/a>/)) {
      seg = substr(rest, RSTART, RLENGTH)
      out = out substr(rest, 1, RSTART - 1)
      rest = substr(rest, RSTART + RLENGTH)
      a = seg; sub(/^<a href="#/, "", a); id = substr(a, 1, index(a, "\"") - 1)
      t = seg; sub(/^<a href="#[^"]*">/, "", t); sub(/<\/a>$/, "", t)
      out = out ((id in ids) ? seg : t)
    }
    print out rest
  }
' "$gen" "$gen" > "$gen.linkfix" && mv "$gen.linkfix" "$gen"

# --- 出力 or 検査 ------------------------------------------------------------
if [ "$mode" = "--check" ]; then
  if [ ! -f "$OUT" ]; then
    echo "drift: $OUT が存在しない（bash scripts/build-docs.sh で生成せよ）" >&2
    echo "docs-sync: 失敗" >&2
    exit 1
  fi
  if ! diff -q "$OUT" "$gen" >/dev/null 2>&1; then
    echo "drift: $OUT がソースのコメントと異なる（bash scripts/build-docs.sh で再生成せよ）" >&2
    diff -u "$OUT" "$gen" | sed -n '3,18p' >&2
    echo "docs-sync: 失敗" >&2
    exit 1
  fi
  echo "docs-sync: 同期OK（モジュール $n 件 / 関数 $funcs 件 / 内部ヘルパー $internal_total 件は非表示）"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
if ! cp "$gen" "$OUT"; then
  echo "error: $OUT の書き出しに失敗" >&2
  exit 1
fi
echo "$OUT 生成完了（モジュール $n 件 / 関数 $funcs 件 / 内部ヘルパー $internal_total 件は非表示）"
