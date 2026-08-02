#!/usr/bin/env bash
# @file scripts/validate-foundation.sh
# @brief 土台（.claude/ の steering 構成とドキュメント規約）の自己検証。
# @description
#   土台の自己検証: .claude/ 配下の steering 構成（settings / hooks / rules / skills / agents / workflows）と
#   ドキュメント規約を機械検証する。「土台が自分自身をテストする」ための中核スクリプト。
#   CI と scripts/check.sh から呼ばれる。
# @exitcode 0 すべての検査に合格
# @exitcode 1 いずれかの検査で違反を検知（最初の1件で打ち切らず全件報告する）
# @stdout 検査ごとの OK 行
# @stderr 違反ごとの NG 行
set -u

fail=0
# @description 違反を報告し fail フラグを立てる（1件目で打ち切らず全件を報告するため）。
# @internal
# @arg $@ string 違反の説明
# @set fail int 1
# @stderr "NG: 説明"
ng() { echo "NG: $*" >&2; fail=1; }
# @description 合格（またはスキップの明示）を報告する。
# @internal
# @arg $@ string 合格した検査の説明
# @stdout "OK: 説明"
ok() { echo "OK: $*"; }
# @description ファイル先頭に frontmatter の開始 --- があるか（CRLF 許容）。
# @internal
# @arg $1 path 検査するファイル
# @exitcode 0 frontmatter で始まる
# @exitcode 1 frontmatter で始まらない
has_fm() { head -1 "$1" | grep -q $'^---\r\{0,1\}$'; }
# @description frontmatter ブロック（2行目から終端 --- まで）を取り出す。
#   frontmatter 内のフィールド（name / description / paths / model）検査に使う。
# @internal
# @arg $1 path 検査するファイル
# @stdout frontmatter の各行
fm() { sed -n $'2,/^---\r\{0,1\}$/p' "$1"; }
# @description frontmatter が終端 --- で閉じているかを判定する。
#   閉じていないと fm() が本文まで舐めてしまい、本文中の `name:` 等を frontmatter の
#   フィールドと誤認して壊れた YAML を見逃す（fail-open）ため、独立して検査する。
# @internal
# @arg $1 path 検査するファイル
# @exitcode 0 終端 --- がある
# @exitcode 1 終端 --- が無い
fm_closed() { awk 'NR>1 { l=$0; sub(/\r$/,"",l); if (l=="---") { found=1; exit } } END { exit(found?0:1) }' "$1"; }
# @description 行数を数える。末尾に改行が無い最終行も1行として数える
#   （wc -l は改行数を数えるため、行数上限の境界で1行少なく出る）。
# @internal
# @arg $1 path 対象ファイル
# @stdout 行数
nlines() { awk 'END{print NR+0}' "$1"; }

cd "$(dirname "$0")/.." || exit 1

# --- 0. JSON 検証ヘルパ（§1 settings.json と §10 プラグインで共有） ---
# 検証ツール（jq/python3）の有無を先に判定する。どちらも無い環境では JSON 検証を
# スキップする（両方欠如で正当な JSON を「不正」と誤判定＝ゲート偽失敗するのを防ぐ）。
# スキップは黙って通さず必ず ok で明示する（判定不能を可視化する）。
if command -v jq >/dev/null 2>&1; then json_tool=jq
elif command -v python3 >/dev/null 2>&1; then json_tool=python3
else json_tool=""; fi
JSON_BOM=$'\xef\xbb\xbf'
# @description JSON ファイルが「トップレベル値ちょうど1個の正しい JSON」かを判定する。
#   jq 経路と python3 経路で同一 verdict を返すことを設計の要件とする
#   （ADR-0013 / rules/tdd.md の二重バックエンド等価性）。検証ツールが無い環境では
#   スキップ（合格扱い）にし、呼び出し側で ok として明示する。
# @internal
# @arg $1 path 検査する JSON ファイル
# @exitcode 0 正しい JSON（または検証ツール不在でスキップ）
# @exitcode 1 ファイルが無い / BOM 付き / 不正な JSON
jsonok() { # file: jq 経路と python3 経路で同一 verdict を返す（ADR-0013 / rules/tdd.md の二重バックエンド等価性）
  [ -f "$1" ] || return 1
  # BOM 付きは JSON.parse（実際の消費側）が失敗するため両経路とも不正扱い。
  # jq は BOM を黙って読み飛ばすため、経路差を消すには先に弾く必要がある。
  [ "$(head -c 3 "$1" 2>/dev/null)" = "$JSON_BOM" ] && return 1
  case "$json_tool" in
    # jq empty は空入力・空白のみ・複数ドキュメント連結を「合格」にしてしまい python3 と
    # verdict が食い違う（インストール済みツールでゲート結果が変わる非決定論）。
    # -s で「トップレベル値がちょうど1個」を要求して json.load と揃える。
    jq)      jq -e -s 'length == 1' "$1" >/dev/null 2>&1 ;;
    python3) python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$1" 2>/dev/null ;;
    *) return 0 ;;   # 検証ツール無し → スキップ（合格扱い。呼び出し側で明示する）
  esac
}

# --- 1. settings.json が正しい JSON か ---
if [ -f .claude/settings.json ]; then
  if [ -z "$json_tool" ]; then
    ok ".claude/settings.json 存在（JSON 検証ツール無しのため構文検査はスキップ）"
  else
    jsonok .claude/settings.json && ok "settings.json は正しい JSON" || ng "settings.json が不正な JSON"
  fi
else
  ng ".claude/settings.json が存在しない"
fi

# --- 2. hooks: 実行可能ビット + シェル構文（+ shellcheck があれば静的解析） ---
for f in .claude/hooks/*.sh scripts/*.sh; do
  [ -f "$f" ] || continue
  [ -x "$f" ] || ng "$f に実行権限がない (chmod +x)"
  # shebang の有無は **shellcheck の有無に依らず**ここで判定する。空ファイルや shebang 無しは
  # `bash -n` を通ってしまう一方 shellcheck は SC2148 で警告するため、この検査を shellcheck に
  # 任せると「インストール済みツール次第でゲート結果が変わる」非決定論になる（Round 9 で CI だけ
  # 赤になった事象）。壊れた hook/script は環境に関わらず落とす（fail-closed・決定論）。
  first=""
  IFS= read -r first < "$f" 2>/dev/null || true
  case "$first" in
    '#!'*) ;;
    *) ng "$f に shebang(#!) が無い（空ファイル含む。hook/script として壊れている）" ;;
  esac
  bash -n "$f" 2>/dev/null && ok "$f 構文OK" || ng "$f にシェル構文エラー"
done
if command -v shellcheck >/dev/null 2>&1; then
  sh_files=()
  for f in .claude/hooks/*.sh scripts/*.sh; do
    [ -f "$f" ] && sh_files+=("$f")
  done
  if [ "${#sh_files[@]}" -gt 0 ]; then
    shellcheck -S warning "${sh_files[@]}" && ok "shellcheck 合格" || ng "shellcheck で警告以上"
  fi
fi

# --- 3. workflows: JS 構文チェック + meta 必須フィールド ---
# workflow は Workflow ツールが本体を async 関数でラップして実行する前提で、トップレベル
# return/await と export const meta を併用する。素の `node --check` は package.json の
# type:module 有無で結果が変わる（スタック導入後に偽陽性）ため、本体を async 関数で
# ラップし export を外してから構文検査する（実行モデルと一致・package.json 非依存）。
for f in .claude/workflows/*.js; do
  [ -f "$f" ] || continue
  if command -v node >/dev/null 2>&1; then
    wf_tmp=$(mktemp --suffix=.js 2>/dev/null || mktemp)
    { printf 'async function __wf(){\n'; sed 's/^export const meta/const meta/' "$f"; printf '\n}\n'; } > "$wf_tmp"
    node --check "$wf_tmp" 2>/dev/null && ok "$f 構文OK" || ng "$f に JS 構文エラー"
    rm -f "$wf_tmp"
  fi
  grep -q "export const meta" "$f" || ng "$f: 'export const meta' が無い"
  # 空白を挟んだ書き方（Date . now / new Date( )）でも検知する
  grep -Eq "Date[[:space:]]*\.[[:space:]]*now|Math[[:space:]]*\.[[:space:]]*random|new[[:space:]]+Date[[:space:]]*\([[:space:]]*\)" "$f" \
    && ng "$f: Date.now/Math.random/new Date() は使用禁止（resume を壊す）"
done

# --- 4. skills: SKILL.md の存在 + frontmatter (name, description) ---
for d in .claude/skills/*/; do
  [ -d "$d" ] || continue
  s="${d}SKILL.md"
  if [ ! -f "$s" ]; then ng "$d に SKILL.md が無い"; continue; fi
  has_fm "$s" || ng "$s: frontmatter が無い"
  if has_fm "$s" && ! fm_closed "$s"; then ng "$s: frontmatter が終端 --- で閉じていない"; fi
  fm "$s" | grep -q '^name:' || ng "$s: frontmatter に name が無い"
  fm "$s" | grep -q '^description:' || ng "$s: frontmatter に description が無い"
  lines=$(nlines "$s")
  [ "$lines" -lt 500 ] && ok "$s (${lines}行)" || ng "$s が500行以上（分割して progressive disclosure にする）"
done

# --- 5. agents: frontmatter (name, description) + モデルはエイリアスのみ ---
for f in .claude/agents/*.md; do
  [ -f "$f" ] || continue
  has_fm "$f" || ng "$f: frontmatter が無い"
  if has_fm "$f" && ! fm_closed "$f"; then ng "$f: frontmatter が終端 --- で閉じていない"; fi
  fm "$f" | grep -q '^name:' || ng "$f: frontmatter に name が無い"
  fm "$f" | grep -q '^description:' || ng "$f: frontmatter に description が無い"
  if fm "$f" | grep -Eq '^model: .*(claude-[a-z0-9-]+-[0-9])' ; then
    ng "$f: model は番号付き固定IDでなくエイリアス (haiku/sonnet/opus/inherit) を使う"
  fi
  ok "$f frontmatter OK"
done

# --- 6. rules: パススコープ規約（paths: frontmatter か、無条件ロードの明示） ---
for f in .claude/rules/*.md; do
  [ -f "$f" ] || continue
  if has_fm "$f"; then
    fm_closed "$f" || ng "$f: frontmatter が終端 --- で閉じていない"
    fm "$f" | grep -q '^paths:' || ng "$f: frontmatter があるのに paths: が無い"
    ok "$f (paths スコープ)"
  else
    grep -q '<!-- unscoped -->' "$f" || ng "$f: 無条件ロードなら先頭に <!-- unscoped --> を明示する"
  fi
done

# --- 7. CLAUDE.md: 存在 + 200行未満 ---
if [ -f CLAUDE.md ]; then
  lines=$(nlines CLAUDE.md)
  [ "$lines" -lt 200 ] && ok "CLAUDE.md (${lines}行)" || ng "CLAUDE.md が200行以上（手順は skills へ、領域規約は rules へ追い出す）"
else
  ng "CLAUDE.md が存在しない"
fi

# --- 8. ADR: 連番形式 + index 同期 + template/README 存在 ---
if [ -d docs/adr ]; then
  [ -f docs/adr/template.md ] || ng "docs/adr/template.md が無い"
  [ -f docs/adr/README.md ] || ng "docs/adr/README.md (index) が無い"
  for f in docs/adr/[0-9]*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    echo "$base" | grep -Eq '^[0-9]{4}-[a-z0-9-]+\.md$' || ng "$f: ファイル名は NNNN-kebab-case.md 形式にする"
    # 固定文字列で照合する（"." を正規表現ワイルドカードとして扱うと 0001-fooXmd のような
    # 綴り違いの index 記載を「載っている」と誤認する）
    grep -qF "$base" docs/adr/README.md || ng "docs/adr/README.md に $base が載っていない（index を更新する）"
  done
  # 逆方向: index に載っているファイルが実在するか
  while IFS= read -r ref; do
    [ -f "docs/adr/$ref" ] || ng "docs/adr/README.md が実在しない $ref を参照している"
  done < <(grep -oE '[0-9]{4}-[a-z0-9-]+\.md' docs/adr/README.md 2>/dev/null | sort -u)
fi

# --- 9. docs/process: プロセス定義の必須ファイルが揃っているか（ADR-0005〜0007） ---
if [ -d docs/process ]; then
  for req in README.md lifecycle.md requirements.md traceability.md verification.md ipa-mapping.md; do
    [ -f "docs/process/$req" ] || ng "docs/process/$req が無い（プロセス定義の欠落）"
  done
  for tpl in requirement-spec test-design postmortem traceability-matrix; do
    [ -f "docs/process/templates/$tpl.md" ] || ng "docs/process/templates/$tpl.md が無い"
  done
fi

# --- 10. コンパニオンプラグイン: マニフェスト/マーケットプレイスの妥当性（ADR-0008） ---
# JSON 検証は §0 の json_tool / jsonok を共有する（§1 settings.json と同じ判定・同じスキップ規則）。
if [ -d plugin ]; then
  for j in .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json plugin/hooks/hooks.json; do
    [ -f "$j" ] || { ng "$j が無い（プラグイン構成の欠落）"; continue; }
    if [ -z "$json_tool" ]; then ok "$j 存在（JSON 検証ツール無しのため構文検査はスキップ）"; else
      jsonok "$j" && ok "$j は正しい JSON" || ng "$j が不正な JSON"; fi
  done
  # plugin.json のトップレベル name のみを取り出して kebab-case を検証（author.name 等に誤爆させない）
  case "$json_tool" in
    jq)      pname=$(jq -r '.name // empty' plugin/.claude-plugin/plugin.json 2>/dev/null) ;;
    python3) pname=$(python3 -c 'import json;print(json.load(open("plugin/.claude-plugin/plugin.json")).get("name",""))' 2>/dev/null) ;;
    *)       pname="" ;;
  esac
  # ツールが有るのに name が空/不正なときだけ NG（ツール無しは検査対象外）
  [ -z "$json_tool" ] || echo "$pname" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || ng "plugin.json のトップレベル name は kebab-case にする（現: '$pname'）"
  # 生成物ディレクトリの存在
  [ -d plugin/skills ] && [ -d plugin/agents ] && [ -d plugin/hooks ] || ng "plugin/{skills,agents,hooks} が揃っていない（build-plugin.sh で生成）"
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "validate-foundation: 失敗" >&2
  exit 1
fi
echo "validate-foundation: すべて合格"
