#!/usr/bin/env bash
# @file scripts/check-docs-structure.sh
# @brief サイト HTML の構成（ピラミッド原則）を構造マーカーで機械検証する。
# @description
#   `.claude/rules/docs.md`（ピラミッド原則の執筆規約）のうち、**構造マーカーで機械判定できる項目**だけを
#   検査する。自然言語の意味解析はしない（誤検知が出ると規約が形骸化するため）。
#   scripts/check.sh から呼ばれる品質ゲート（ADR-0004。ゲートは check.sh 単一入口に足す）。
#
#   検査対象: docs/reference.html / docs/guide.html のうち存在するもの。
#   リポジトリ直下の index.html は Vite のエントリーポイントであり文書ではないので対象外。
#   `<main>` があればその中だけを見る（無ければ文書全体）。`<svg>` / `<code>` / `<pre>` /
#   `<template>` の中身は構造として数えない（図中のラベルやコード例を markup と誤認しないため）。
#
#   検査:
#     0) 用語集の正本が `.claude/rules/docs.md` と本スクリプトで一致する（規約と検査の乖離防止）
#     1) 見出しを持つ `<section>` は、見出しの直後が `<p class="answer">`（結論 → 根拠 → 詳細）
#     2) `<p class="answer">` は1文（句点 `。` は1つまで）かつ空でない
#     3) 見出し階層を飛ばさない（h2 の次に h4 を置かない）
#     4) 見出しブロックに `<figure>` があるなら、本文段落（`.answer` 以外の `<p>`）より前にある
#     5) 用語集の語の初出が `<abbr title="…">` か `class="term"` の中にある（除外規則は rules/docs.md）
#     6) `@keyframes` を使うファイルには `prefers-reduced-motion` の指定がある
#
#   判定に必要な gawk が無い環境では、判定不能を合格に倒さず明示メッセージで非ゼロ終了する（fail-closed）。
# @exitcode 0 全ファイルが規約に適合（対象ファイルが1つも無い場合も合格）
# @exitcode 1 違反を検知、または検査不能（gawk が無い）
# @exitcode 2 使い方の誤り（引数を受け取らない）
# @stdout 合格時の件数要約
# @stderr 違反ごとの "NG(docs): ファイル:行 …"
set -u

# 決定論性のためロケールを固定する。gawk の文字境界（substr/length のバイト単位）・正規表現の
# 文字クラス・大文字小文字変換がロケールで揺れると、同じ HTML から違う判定が出てしまう。
export LC_ALL=C
export LANG=C

# 検査0 が自分自身の TERMS を読むので、cd の前に絶対パスへ解決しておく
# （相対パスの $0 は cd 後に解決できなくなる）。
self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

cd "$(dirname "$self")/.." || exit 1

# 未知引数を「検査」に倒すと綴り誤りに気づけないため、引数は受け取らない（build-docs.sh と同じ方針）。
if [ "$#" -gt 0 ]; then
  echo "usage: bash scripts/check-docs-structure.sh（引数は取らない。渡された引数: $*）" >&2
  exit 2
fi

fail=0
# @description 違反を報告し fail フラグを立てる（1件目で打ち切らず全件を報告するため）。
# @internal
# @arg $@ string 違反の説明
# @set fail int 1
# @stderr "NG(docs): 説明"
ng() { echo "NG(docs): $*" >&2; fail=1; }

# 判定不能（ツール欠落）は合格に倒さない。黙って通すと規約が形骸化する。
if ! command -v gawk >/dev/null 2>&1; then
  ng "gawk が見つからない（HTML の構造判定ができない）。導入せよ: apt-get install -y gawk"
  echo "docs-structure: 失敗（検査不能。判定不能は合格に倒さない）" >&2
  exit 1
fi

# 検査対象は docs/ 配下のサイト HTML のみ。リポジトリ直下の index.html は Vite の
# エントリーポイント（アプリの実体）であって文書ではないため、対象に含めない
# （含めると app のマークアップを文書規約で誤検査して偽失敗する）。
targets=(docs/reference.html docs/guide.html)
files=()
for f in "${targets[@]}"; do
  [ -f "$f" ] && files+=("$f")
done

if [ "${#files[@]}" -eq 0 ]; then
  echo "docs-structure: 合格（対象ファイルなし: ${targets[*]} のいずれも存在しない）"
  exit 0
fi

# 検査0: 用語集の正本が2箇所（規約の文章と、下の awk の TERMS）にあるので、両者の一致を機械で固定する。
# 片方だけ増やすと「規約には書いたが検査されない語」が生まれ、規約が静かに形骸化する
# （check-skill-sync.sh と同じ「一覧と実体の同期」パターン）。
rule_md=".claude/rules/docs.md"
if [ ! -f "$rule_md" ]; then
  ng "$rule_md が無い（用語集の正本を照合できない）"
else
  rule_terms=$(gawk '
    /用語集の正本/ { collect = 1; next }
    collect && /^[[:space:]]*$/ { exit }
    collect { s = $0; while (match(s, /`[^`]+`/)) { print substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH) } }
  ' "$rule_md")
  code_terms=$(gawk 'match($0, /^[[:space:]]*TERMS\[\+\+TN\][[:space:]]*=[[:space:]]*"([^"]*)"/, m) { print m[1] }' "$self")
  if [ -z "$rule_terms" ]; then
    ng "$rule_md から用語集を読み取れない（「用語集の正本」の直後に \`語\` の一覧を置く）"
  elif [ -z "$code_terms" ]; then
    ng "scripts/check-docs-structure.sh から TERMS 一覧を読み取れない（検査が空振りする）"
  elif [ "$rule_terms" != "$code_terms" ]; then
    ng "用語集が $rule_md と scripts/check-docs-structure.sh で食い違う（同じ順・同じ表記で持つこと）:"
    diff <(printf '%s\n' "$rule_terms") <(printf '%s\n' "$code_terms") >&2 || true
  fi
fi

# @description 1ファイルを gawk で解析し、違反を stderr へ、件数を stdout の "STATS …" 行へ出す。
#   ファイル名は awk -v ではなく **ENVIRON 経由**で渡す（awk -v は値のエスケープシーケンスを解釈し、
#   実装差で挙動が変わるため。check-skill-sync.sh と同じ既知事項）。
# @internal
# @arg $1 string 対象 HTML のパス
# @stdout "STATS <section数> <見出し数> <結論段落数> <用語初出数>"
# @stderr 違反ごとの "NG(docs): ファイル:行 …"
# @exitcode 0 違反なし / 1 違反あり
scan_file() {
  DOCS_FILE="$1" gawk '
function trim(s) { gsub(/^[ \t\r\n]+/, "", s); gsub(/[ \t\r\n]+$/, "", s); return s }

# 文字列 t の出現回数（正規表現ではなく素の文字列として数える）
function count_str(s, t,   c, p, k) {
  c = 0; p = 1
  while ((k = index(substr(s, p), t)) > 0) { c++; p = p + k - 1 + length(t) }
  return c
}

# 違反を報告する（1件目で打ち切らず全件を出す）
function ng(line, msg) {
  printf "NG(docs): %s:%d %s\n", FNAME, line, msg > "/dev/stderr"
  nfail++
}

# 同じ長さの空白へ潰す（位置と行番号を保つため改行だけ残す）
function blankspan(s) { gsub(/[^\n]/, " ", s); return s }

# HTML コメントを潰す（コメント内の偽タグを構造と誤認しないため）
function blank_comments(s,   p, a, b, mid) {
  p = 1
  while ((a = index(substr(s, p), "<!--")) > 0) {
    a = p + a - 1
    b = index(substr(s, a), "-->")
    if (b == 0) break
    b = a + b - 1 + 2
    mid = substr(s, a, b - a + 1)
    s = substr(s, 1, a - 1) blankspan(mid) substr(s, b + 1)
    p = b + 1
  }
  return s
}

# 指定要素の**中身だけ**を潰す（script/style 内の文字列を markup と誤認しないため。タグ自体は残す）
function blank_element(s, name,   low, p, a, nxt, gt, crel, cstart, mid) {
  p = 1
  while (1) {
    low = tolower(s)
    a = index(substr(low, p), "<" name)
    if (a == 0) break
    a = p + a - 1
    nxt = substr(low, a + length(name) + 1, 1)
    if (nxt ~ /[a-z0-9]/) { p = a + 1; continue }
    gt = index(substr(s, a), ">")
    if (gt == 0) break
    gt = a + gt - 1
    crel = index(substr(low, gt + 1), "</" name)
    if (crel == 0) { p = gt + 1; continue }
    cstart = gt + crel
    mid = substr(s, gt + 1, crel - 1)
    s = substr(s, 1, gt) blankspan(mid) substr(s, cstart)
    p = cstart
  }
  return s
}

# 属性値を取り出す（二重引用符のみ対応。HTML の慣例に合わせる）
function attrval(attrs, key,   v) {
  if (!match(attrs, "(^|[ \t\r\n])" key "[ \t\r\n]*=[ \t\r\n]*\"[^\"]*\"")) return ""
  v = substr(attrs, RSTART, RLENGTH)
  sub(/^[^=]*=[ \t\r\n]*"/, "", v)
  sub(/"$/, "", v)
  return v
}

# class 属性に指定トークンが含まれるか（部分一致ではなく空白区切りの完全一致）
function hasclass(attrs, want,   v, n, a, i) {
  v = attrval(attrs, "class")
  if (v == "") return 0
  n = split(v, a, /[ \t\r\n]+/)
  for (i = 1; i <= n; i++) if (a[i] == want) return 1
  return 0
}

function nlcount(s,   c) { c = gsub(/\n/, "\n", s); return c }

function addtext(t) {
  if (t == "") return
  ntok++; T_type[ntok] = "t"; T_text[ntok] = t; T_line[ntok] = curline
  curline += nlcount(t)
}

function addtag(tagstr,   name, attrs) {
  ntok++
  T_line[ntok] = curline
  if (substr(tagstr, 1, 1) == "/") {
    T_type[ntok] = "c"
    name = substr(tagstr, 2)
    sub(/[ \t\r\n\/].*$/, "", name)
    T_name[ntok] = tolower(name)
    T_attr[ntok] = ""
    T_void[ntok] = 0
  } else {
    T_type[ntok] = "o"
    name = tagstr
    sub(/[ \t\r\n\/].*$/, "", name)
    T_name[ntok] = tolower(name)
    attrs = substr(tagstr, length(name) + 1)
    T_attr[ntok] = tolower(attrs)
    T_void[ntok] = (VOID[T_name[ntok]] || tagstr ~ /\/[ \t\r\n]*$/) ? 1 : 0
  }
  curline += nlcount(tagstr)
}

# "<" で分割してタグ列とテキスト列に分ける（O(n)。属性値内の "<" は HTML では書けない前提）
function tokenize(   n, i, part, gt, tagstr, rest) {
  ntok = 0; curline = 1
  n = split(doc, P, "<")
  addtext(P[1])
  for (i = 2; i <= n; i++) {
    part = P[i]
    gt = index(part, ">")
    if (gt == 0) { addtext("<" part); continue }
    tagstr = substr(part, 1, gt - 1)
    rest = substr(part, gt + 1)
    if (tagstr ~ /^\/?[A-Za-z]/) addtag(tagstr); else addtext("<" tagstr ">")
    addtext(rest)
  }
}

function bump(k, d) { C[k] += d }
function bumpmarks(m, d,   n, a, i) {
  if (m == "") return
  n = split(m, a, " ")
  for (i = 1; i <= n; i++) C[a[i]] += d
}

# 注釈（用語）・用語集の印を付ける
function marks_of(i,   m) {
  m = ""
  if ((T_name[i] == "abbr" && attrval(T_attr[i], "title") != "") || hasclass(T_attr[i], "term")) m = m " ANNOT"
  if (hasclass(T_attr[i], "glossary")) m = m " GLOSSARY"
  return m
}

# トークンごとに「どの領域の中か」を記録する
function setflags(i,   heads) {
  heads = C["h1"] + C["h2"] + C["h3"] + C["h4"] + C["h5"] + C["h6"]
  T_ex[i] = (C["head"] + C["script"] + C["style"] + C["code"] + C["pre"] + C["kbd"] + C["samp"] \
             + C["nav"] + C["footer"] + C["svg"] + C["GLOSSARY"] + heads) > 0 ? 1 : 0
  T_annot[i] = (C["ANNOT"] > 0) ? 1 : 0
  T_infig[i] = (C["figure"] > 0) ? 1 : 0
  T_struct[i] = ((C["svg"] + C["code"] + C["pre"] + C["template"] + C["head"]) == 0 \
                 && (!has_main || C["main"] > 0)) ? 1 : 0
}

# 開始タグのスタックを持ち、閉じタグは「一致する所まで巻き戻す」（閉じ忘れに強い HTML 的な回復）
function annotate(   i, k, found) {
  sp = 0
  has_main = 0
  for (i = 1; i <= ntok; i++) if (T_type[i] == "o" && T_name[i] == "main") { has_main = 1; break }
  for (i = 1; i <= ntok; i++) {
    if (T_type[i] == "o") {
      setflags(i)
      if (!T_void[i]) {
        sp++
        ST[sp] = T_name[i]
        MK[sp] = marks_of(i)
        bump(ST[sp], 1); bumpmarks(MK[sp], 1)
      }
    } else if (T_type[i] == "c") {
      setflags(i)
      found = 0
      for (k = sp; k >= 1; k--) if (ST[k] == T_name[i]) { found = k; break }
      if (found) {
        for (k = sp; k >= found; k--) { bump(ST[k], -1); bumpmarks(MK[k], -1) }
        sp = found - 1
      }
    } else {
      setflags(i)
    }
  }
}

# 検査1: 見出しを持つ section は、見出しの直後が <p class="answer">
function check_sections(   i, j, k, m, hi, txt, sid) {
  for (i = 1; i <= ntok; i++) {
    if (T_type[i] != "o" || T_name[i] != "section" || !T_struct[i]) continue
    n_sections++
    sid = attrval(T_attr[i], "id")
    sid = (sid == "") ? "(id なし)" : "#" sid
    hi = 0
    for (j = i + 1; j <= ntok; j++) {
      if (!T_struct[j]) continue
      if (T_type[j] == "o" && T_name[j] == "section") break
      if (T_type[j] == "c" && T_name[j] == "section") break
      if (T_type[j] == "o" && T_name[j] ~ /^h[1-6]$/) { hi = j; break }
    }
    if (hi == 0) continue   # 見出しを持たない構造用 section は対象外（rules/docs.md）
    for (k = hi + 1; k <= ntok; k++) if (T_type[k] == "c" && T_name[k] == T_name[hi]) break
    for (m = k + 1; m <= ntok; m++) {
      if (!T_struct[m]) continue
      if (T_type[m] == "c") continue
      if (T_type[m] == "t") {
        txt = trim(T_text[m])
        if (txt == "") continue
        ng(T_line[m], "section " sid " の見出し <" T_name[hi] "> の直後に地の文がある（結論は <p class=\"answer\"> に書く）")
        break
      }
      if (T_name[m] == "p" && hasclass(T_attr[m], "answer")) break
      ng(T_line[m], "section " sid " の見出し <" T_name[hi] "> の直後が <p class=\"answer\"> でない（見つかったのは <" T_name[m] ">。結論 → 根拠 → 詳細の順に書く）")
      break
    }
    if (m > ntok) ng(T_line[hi], "section " sid " の見出し <" T_name[hi] "> の後に <p class=\"answer\"> が無い")
  }
}

# 検査2: 結論は1文（句点は1つまで）かつ空でない
function check_answers(   i, j, txt, dots) {
  for (i = 1; i <= ntok; i++) {
    if (T_type[i] != "o" || T_name[i] != "p" || !T_struct[i]) continue
    if (!hasclass(T_attr[i], "answer")) continue
    n_answers++
    txt = ""
    for (j = i + 1; j <= ntok; j++) {
      if (T_type[j] == "c" && T_name[j] == "p") break
      if (T_type[j] == "o" && T_name[j] ~ /^(p|div|section|figure|main|article|ul|ol|table|h[1-6])$/) break
      if (T_type[j] == "c" && T_name[j] ~ /^(section|main|article|div)$/) break
      if (T_type[j] == "t") txt = txt T_text[j]
    }
    if (trim(txt) == "") {
      ng(T_line[i], "結論段落 <p class=\"answer\"> が空（節の答えを1文で書く）")
      continue
    }
    dots = count_str(txt, "。")
    if (dots >= 2) ng(T_line[i], "結論段落が " dots " 文ある（<p class=\"answer\"> は句点1つまで。1文にならない結論は節を割る）")
  }
}

# 検査3: 見出し階層を飛ばさない
function check_heading_levels(   i, lv, prev) {
  prev = 0
  for (i = 1; i <= ntok; i++) {
    if (T_type[i] != "o" || T_name[i] !~ /^h[1-6]$/ || !T_struct[i]) continue
    n_headings++
    lv = substr(T_name[i], 2) + 0
    if (prev > 0 && lv > prev + 1) ng(T_line[i], "見出し階層を飛ばしている（h" prev " の次に h" lv "）")
    prev = lv
  }
}

# 検査4: 見出しブロック内で図は本文段落より先
function check_figures(   i, j, ff, fp) {
  for (i = 1; i <= ntok; i++) {
    if (T_type[i] != "o" || T_name[i] !~ /^h[1-6]$/ || !T_struct[i]) continue
    ff = 0; fp = 0
    for (j = i + 1; j <= ntok; j++) {
      if (!T_struct[j]) continue
      if (T_type[j] == "o" && (T_name[j] ~ /^h[1-6]$/ || T_name[j] == "section")) break
      if (T_type[j] == "c" && (T_name[j] == "section" || T_name[j] == "main")) break
      if (T_type[j] != "o") continue
      if (T_name[j] == "figure" && !T_infig[j] && ff == 0) ff = j
      if (T_name[j] == "p" && !T_infig[j] && fp == 0 && !hasclass(T_attr[j], "answer")) fp = j
    }
    if (ff > 0 && fp > 0 && ff > fp) {
      n_figs++
      ng(T_line[ff], "図が本文より後にある（" T_line[fp] " 行目の <p> より前に <figure> を置く。図が呼び水、文は補足）")
    } else if (ff > 0) {
      n_figs++
    }
  }
}

# 用語の出現位置を返す（0＝無し）。英数字で始まる/終わる語は語境界を要求する（deb と debug を区別）
function term_hit(txt, term,   p, start, before, after, tl, sl, el) {
  tl = length(term)
  sl = (term ~ /^[A-Za-z0-9]/)
  el = (term ~ /[A-Za-z0-9]$/)
  p = 1
  while ((start = index(substr(txt, p), term)) > 0) {
    start = p + start - 1
    before = (start > 1) ? substr(txt, start - 1, 1) : ""
    after = substr(txt, start + tl, 1)
    if ((!sl || before !~ /[A-Za-z0-9]/) && (!el || after !~ /[A-Za-z0-9]/)) return start
    p = start + 1
  }
  return 0
}

# 検査5: 用語集の語の初出に注釈がある（除外領域は setflags の T_ex）
function check_terms(   t, i, done) {
  for (t = 1; t <= TN; t++) {
    done = 0
    for (i = 1; i <= ntok && !done; i++) {
      if (T_type[i] != "t" || T_ex[i]) continue
      if (has_main && !T_struct[i]) continue
      if (term_hit(T_text[i], TERMS[t]) == 0) continue
      done = 1
      n_terms++
      if (!T_annot[i]) ng(T_line[i], "用語 「" TERMS[t] "」 の初出に注釈が無い（<abbr title=\"1行の定義\"> か class=\"term\" で囲む）")
    }
  }
}

# 検査6: アニメーションは reduced-motion を尊重する
function check_motion() {
  if (has_kf && !has_rm) ng(1, "@keyframes があるのに prefers-reduced-motion の指定が無い（動きを止められない）")
}

BEGIN {
  IGNORECASE = 0
  FNAME = ENVIRON["DOCS_FILE"]
  nfail = 0
  n_sections = 0; n_headings = 0; n_answers = 0; n_terms = 0; n_figs = 0
  split("area base br col embed hr img input link meta param source track wbr", vl, " ")
  for (vi in vl) VOID[vl[vi]] = 1
  # 用語集の正本（イシュー #50）。.claude/rules/docs.md の一覧と同じ順・同じ表記で持つ。
  TN = 0
  TERMS[++TN] = "deb"
  TERMS[++TN] = "steering"
  TERMS[++TN] = "機構"
  TERMS[++TN] = "品質ゲート"
  TERMS[++TN] = "フック"
  TERMS[++TN] = "Stop フック"
  TERMS[++TN] = "ADR"
  TERMS[++TN] = "MAPE-K"
  TERMS[++TN] = "fail-closed"
  TERMS[++TN] = "トレーサビリティ"
  TERMS[++TN] = "テーラリング"
  TERMS[++TN] = "ラウンド"
  TERMS[++TN] = "ドラフト PR"
  TERMS[++TN] = "サーキットブレーカー"
  TERMS[++TN] = "safe-state"
  TERMS[++TN] = "shdoc"
}

{
  doc = doc $0 "\n"
  if ($0 ~ /@keyframes/) has_kf = 1
  if ($0 ~ /prefers-reduced-motion/) has_rm = 1
}

END {
  doc = blank_comments(doc)
  doc = blank_element(doc, "script")
  doc = blank_element(doc, "style")
  tokenize()
  annotate()
  check_sections()
  check_answers()
  check_heading_levels()
  check_figures()
  check_terms()
  check_motion()
  printf "STATS %d %d %d %d %d\n", n_sections, n_headings, n_answers, n_figs, n_terms
  exit (nfail > 0 ? 1 : 0)
}
' "$1"
}

tot_sec=0; tot_head=0; tot_ans=0; tot_fig=0; tot_term=0
for f in "${files[@]}"; do
  out=$(scan_file "$f")
  rc=$?
  [ "$rc" -ne 0 ] && fail=1
  read -r _ s h a g t <<< "$out"
  tot_sec=$((tot_sec + ${s:-0}))
  tot_head=$((tot_head + ${h:-0}))
  tot_ans=$((tot_ans + ${a:-0}))
  tot_fig=$((tot_fig + ${g:-0}))
  tot_term=$((tot_term + ${t:-0}))
done

if [ "$fail" -ne 0 ]; then
  echo "docs-structure: 失敗（規約は .claude/rules/docs.md）" >&2
  exit 1
fi
echo "docs-structure: 合格（HTML ${#files[@]} 件 / section $tot_sec 件 / 見出し $tot_head 件 / 結論段落 $tot_ans 件 / 図 $tot_fig 件 / 用語初出 $tot_term 件を検査）"
