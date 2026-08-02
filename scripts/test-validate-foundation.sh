#!/usr/bin/env bash
# @file scripts/test-validate-foundation.sh
# @brief validate-foundation.sh の網羅テスト（構造ルールごとに正常系/異常系を突く）。
# @description
#   validate-foundation.sh の網羅テスト（構造ルールごとに 正常系 / 異常系 を突く）。
#
#   本テストの本質は「検査が実際に違反を検知できるか」。ルールを1つずつ意図的に破った
#   フィクスチャ（mktemp -d の最小土台）を作り、validate-foundation.sh が非ゼロで落ちること
#   （＝嘘をつかないこと）と、正しい構成では落ちないこと（＝過剰検知しないこと）を固定する。
#   実リポジトリの内容には依存させない（決定論。実リポジトリは読み取りのみ）。
#
#   背景（ドッグフーディングで発見）: workflow の .js は Workflow ツールが本体を async 関数で
#   ラップして実行する前提で、トップレベル return/await と export const meta を併用する。
#   素の `node --check` は package.json の type:module 有無で結果が変わり、スタック導入後
#   （type:module）に workflow を「構文エラー」と誤判定していた。ラップ検査に修正済み。
#   回帰ケース A/B/C はその再発防止（実リポジトリのコピーで検証）。
# @exitcode 0 全ケース合格（node が無い環境ではスキップして 0）
# @exitcode 1 いずれかのケースが不合格
# @stdout ケースごとの PASS 行とアサーション数
# @stderr 不合格ケースの FAIL 行
set -u

cd "$(dirname "$0")/.." || exit 1
command -v node >/dev/null 2>&1 || { echo "test-validate-foundation: node 無しでスキップ"; exit 0; }

fail=0
count=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# @description ケースの合格を記録する。
# @internal
# @arg $1 string ケースの説明
# @set count int アサーション数を1増やす
# @stdout "PASS: 説明"
pass_() { count=$((count + 1)); echo "PASS: $1"; }
# @description ケースの不合格を記録する。
# @internal
# @arg $1 string ケースの説明
# @set count int アサーション数を1増やす
# @set fail int 1
# @stderr "FAIL: 説明"
fail_() { count=$((count + 1)); echo "FAIL: $1" >&2; fail=1; }

# ============================================================================
# 回帰ケース A-C: 実リポジトリのコピーで固定（既存ケース）
# ============================================================================
repo=$work/repo
mkdir -p "$repo"
# 現在の作業ツリー（.git / node_modules 除く）を隔離コピー
tar --exclude=./.git --exclude=./node_modules -cf - . 2>/dev/null | (cd "$repo" && tar xf -)
# スタック導入後を模して package.json（type:module）を置く
printf '{\n  "name": "fixture",\n  "type": "module"\n}\n' > "$repo/package.json"

# ケースA: type:module 環境でも foundation 検証が通る（workflow 誤判定の回帰）
( cd "$repo" && bash scripts/validate-foundation.sh >/dev/null 2>&1 )
if [ $? -eq 0 ]; then pass_ "type:module 環境でも foundation 検証が通る"; else fail_ "type:module 環境で foundation 検証が失敗"; fi

# ケースB: jq も python3 も無い環境でも plugin JSON 検証で偽失敗しない（§10 の非対称回帰）
#   （workflow を壊す前のクリーンなコピーで実行する）
sb=$work/nobin-parser
mkdir -p "$sb"
for tool in bash sh awk sed grep sort uniq head tail wc find cat basename dirname tr cut git node cksum mktemp rm chmod ls printf; do
  p=$(command -v "$tool" 2>/dev/null); [ -n "$p" ] && ln -sf "$p" "$sb/$tool"
done
( cd "$repo" && PATH="$sb" bash scripts/validate-foundation.sh >"$work/.vfB.log" 2>&1 ); ec=$?
if [ "$ec" -eq 0 ] && ! grep -q '不正な JSON' "$work/.vfB.log"; then
  pass_ "jq/python3 なしでも plugin JSON で偽失敗しない"
else
  fail_ "jq/python3 なしで plugin JSON が偽失敗（exit=$ec）"
fi

# ケースC: 壊れた workflow は構文エラーとして捕捉する
wf=$(find "$repo/.claude/workflows" -name '*.js' | head -1)
if [ -n "$wf" ]; then
  printf '\nconst broken = (\n' >> "$wf"   # 未閉じ括弧
  ( cd "$repo" && bash scripts/validate-foundation.sh >/dev/null 2>&1 )
  if [ $? -ne 0 ]; then pass_ "壊れた workflow を構文エラーで捕捉"; else fail_ "壊れた workflow を見逃した"; fi
else
  fail_ "テスト対象の workflow が見つからない"
fi
rm -rf "$repo"

# ============================================================================
# フィクスチャ基盤: 最小の「正しい土台」を組み立て、ルールを1つずつ破る
# ============================================================================
base=$work/base
mkdir -p "$base/scripts" "$base/.claude/hooks" "$base/.claude/workflows" "$base/.claude/skills/demo" \
         "$base/.claude/agents" "$base/.claude/rules" "$base/docs/adr" "$base/docs/process/templates" \
         "$base/.claude-plugin" "$base/plugin/.claude-plugin" "$base/plugin/hooks" \
         "$base/plugin/skills" "$base/plugin/agents"
cp scripts/validate-foundation.sh "$base/scripts/validate-foundation.sh"
chmod +x "$base/scripts/validate-foundation.sh"

# @description n 行のテキストファイル（末尾改行あり）を作る。行数上限の検査に使う。
# @internal
# @arg $1 int 行数
# @arg $2 path 出力先
lines_file() { awk -v n="$1" 'BEGIN{ for (i = 0; i < n; i++) print "x" }' > "$2"; }
# @description n 行のテキストファイル（最終行に改行なし＝境界値の突きどころ）を作る。
# @internal
# @arg $1 int 行数
# @arg $2 path 出力先
lines_file_nonl() { awk -v n="$1" 'BEGIN{ for (i = 0; i < n - 1; i++) print "x"; printf "x" }' > "$2"; }
# @description frontmatter 4行 + 本文で合計 n 行の SKILL.md を作る（末尾改行あり）。
# @internal
# @arg $1 int 合計行数
# @arg $2 path 出力先
skill_file() { { printf -- '---\nname: demo\ndescription: demo skill\n---\n'; awk -v n="$(($1 - 4))" 'BEGIN{ for (i = 0; i < n; i++) print "x" }'; } > "$2"; }
# @description skill_file と同じだが最終行に改行を付けない（行数境界の突きどころ）。
# @internal
# @arg $1 int 合計行数
# @arg $2 path 出力先
skill_file_nonl() { { printf -- '---\nname: demo\ndescription: demo skill\n---\n'; awk -v n="$(($1 - 4))" 'BEGIN{ for (i = 0; i < n - 1; i++) print "x"; printf "x" }'; } > "$2"; }

printf '# fixture\n\nfoundation fixture.\n' > "$base/CLAUDE.md"
printf '{\n  "hooks": {}\n}\n' > "$base/.claude/settings.json"
printf '#!/usr/bin/env bash\nset -u\nexit 0\n' > "$base/.claude/hooks/demo.sh"
chmod +x "$base/.claude/hooks/demo.sh"
{ printf 'export const meta = {\n  name: %s,\n  description: %s,\n};\n' "'demo'" "'demo workflow'"
  printf 'const x = 1;\nreturn x;\n'; } > "$base/.claude/workflows/demo.js"
skill_file 6 "$base/.claude/skills/demo/SKILL.md"
printf -- '---\nname: demo-agent\ndescription: demo agent\nmodel: inherit\n---\n\nbody\n' > "$base/.claude/agents/demo.md"
printf -- '---\npaths: ["src/**"]\n---\n\nscoped rule\n' > "$base/.claude/rules/scoped.md"
printf -- '<!-- unscoped -->\n\nunscoped rule\n' > "$base/.claude/rules/unscoped.md"
printf '# ADR 0001\n' > "$base/docs/adr/0001-demo-decision.md"
printf '# ADR index\n\n- [0001](0001-demo-decision.md)\n' > "$base/docs/adr/README.md"
printf '# template\n' > "$base/docs/adr/template.md"
for f in README lifecycle requirements traceability verification ipa-mapping; do printf '# %s\n' "$f" > "$base/docs/process/$f.md"; done
for f in requirement-spec test-design postmortem traceability-matrix; do printf '# %s\n' "$f" > "$base/docs/process/templates/$f.md"; done
printf '{\n  "name": "deb",\n  "plugins": []\n}\n' > "$base/.claude-plugin/marketplace.json"
printf '{\n  "name": "deb-companion",\n  "version": "0.1.0"\n}\n' > "$base/plugin/.claude-plugin/plugin.json"
printf '{\n  "hooks": {}\n}\n' > "$base/plugin/hooks/hooks.json"

fixn=0
d=""
LOG=""
# @description 正しい土台（$base）の新しいコピーを作り、$d を指し替える。ケースごとに独立させる。
# @internal
# @set d path 新しいフィクスチャのディレクトリ
# @set fixn int 連番を1増やす
newfix() { fixn=$((fixn + 1)); d="$work/f$fixn"; rm -rf "$d"; cp -a "$base" "$d"; }
# @description 現在のフィクスチャ $d で validate-foundation.sh を実行する。
# @internal
# @set LOG path 出力（stdout+stderr）を保存したログファイル
# @exitcode * validate-foundation.sh の終了コードをそのまま返す
run_vf() { LOG="$work/vf.log"; ( cd "$d" && bash scripts/validate-foundation.sh ) >"$LOG" 2>&1; }
# @description run_vf と同じだが、環境変数（PATH / LC_ALL 等）を差し替えて実行する。
# @internal
# @arg $@ string env に渡す VAR=value の並び
# @set LOG path 出力（stdout+stderr）を保存したログファイル
# @exitcode * validate-foundation.sh の終了コードをそのまま返す
run_vf_env() { LOG="$work/vf.log"; ( cd "$d" && env "$@" bash scripts/validate-foundation.sh ) >"$LOG" 2>&1; }

# 異常系: 変異を加えると非ゼロで落ち、期待の NG メッセージが出ること
# @description 異常系ケース。土台に変異を加えると非ゼロで落ち、期待の NG メッセージが出ることを検査する
#   （見逃し＝fail-open と、別の理由での失敗を区別する）。
# @internal
# @arg $1 string ケースの説明
# @arg $2 string 期待する NG メッセージの部分文字列
# @arg $3 string フィクスチャに適用する変異コード（eval される）
# @set fail int 見逃し・メッセージ不一致なら 1
ng_case() { # desc, 期待NG部分文字列, 変異コード
  newfix
  eval "$3"
  run_vf; ec=$?
  if [ "$ec" -ne 0 ] && grep -qF "$2" "$LOG"; then
    pass_ "検知: $1"
  elif [ "$ec" -ne 0 ]; then
    fail_ "検知したが NG メッセージが違う: $1 (期待='$2')"
  else
    fail_ "見逃し（fail-open）: $1"
  fi
  rm -rf "$d"
}
# 正常系: 正しい（もしくは規約上許される）変形では落ちないこと
# @description 正常系ケース。規約上許される変形では落ちないこと（過剰検知しないこと）を検査する。
# @internal
# @arg $1 string ケースの説明
# @arg $2 string フィクスチャに適用する変異コード（eval される）
# @set fail int 過剰検知したら 1
ok_case() { # desc, 変異コード
  newfix
  eval "$2"
  run_vf; ec=$?
  if [ "$ec" -eq 0 ]; then pass_ "合格: $1"
  else fail_ "過剰検知: $1 ($(grep -m1 '^NG' "$LOG"))"; fi
  rm -rf "$d"
}

# ============================================================================
# §0/§1 settings.json: 存在 + 正しい JSON（jq/python3 の二重バックエンド等価性）
# ============================================================================
ok_case "既定のフィクスチャ構成"            ':'
ng_case "settings.json が無い"              ".claude/settings.json が存在しない" 'rm "$d/.claude/settings.json"'
ng_case "settings.json が不正な JSON"       "settings.json が不正な JSON" 'printf "{oops" > "$d/.claude/settings.json"'
ng_case "settings.json が空ファイル"        "settings.json が不正な JSON" ': > "$d/.claude/settings.json"'
ng_case "settings.json が空白のみ"          "settings.json が不正な JSON" 'printf "   \n\n" > "$d/.claude/settings.json"'
ng_case "settings.json が複数ドキュメント連結" "settings.json が不正な JSON" 'printf "{\"a\":1} {\"b\":2}\n" > "$d/.claude/settings.json"'
ng_case "settings.json が BOM 付き"         "settings.json が不正な JSON" 'printf "\357\273\277{\"a\":1}\n" > "$d/.claude/settings.json"'
ng_case "settings.json が JSON でなく YAML" "settings.json が不正な JSON" 'printf "hooks:\n  - a\n" > "$d/.claude/settings.json"'
ng_case "settings.json の末尾にゴミが付く"  "settings.json が不正な JSON" 'printf "{\"a\":1}\ntrailing\n" > "$d/.claude/settings.json"'
ok_case "settings.json に日本語を含む"      'printf "{\"desc\": \"日本語のせつめい\"}\n" > "$d/.claude/settings.json"'
ok_case "settings.json がトップレベル配列"  'printf "[1, 2, 3]\n" > "$d/.claude/settings.json"'
ok_case "settings.json が巨大（5000キー）"  'python3 -c "
import json
json.dump({(\"k%d\" % i): i for i in range(5000)}, open(\"$d/.claude/settings.json\", \"w\"))
"'

# ============================================================================
# §2 hooks / scripts: 実行可能ビット + シェル構文
# ============================================================================
ng_case "hook に実行権限が無い"             "実行権限がない" 'chmod -x "$d/.claude/hooks/demo.sh"'
ng_case "hook にシェル構文エラー"           "シェル構文エラー" 'printf "if [ 1 ]; then\n" >> "$d/.claude/hooks/demo.sh"'
ng_case "hook が未閉じクォート"             "シェル構文エラー" 'printf "echo \"unterminated\n" >> "$d/.claude/hooks/demo.sh"'
ng_case "scripts/*.sh に実行権限が無い"     "実行権限がない" 'printf "#!/usr/bin/env bash\nexit 0\n" > "$d/scripts/extra.sh"'
ng_case "scripts/*.sh にシェル構文エラー"   "シェル構文エラー" 'printf "#!/usr/bin/env bash\ncase x in\n" > "$d/scripts/extra.sh"; chmod +x "$d/scripts/extra.sh"'
ok_case "hooks に .sh 以外があっても無視"   'printf "not a script\n" > "$d/.claude/hooks/README.md"'
# 空の hook は `bash -n` は通るが hook として壊れている。shellcheck の有無で verdict が
# 変わらないよう、shebang 検査で無条件に検知する（Round 9: CI だけ赤になった非決定論の回帰）
ng_case "hook が空ファイル（shebang 無し）" "shebang" ': > "$d/.claude/hooks/demo.sh"'
ok_case "最小の正しい hook（shebang あり）"  'printf "#!/usr/bin/env bash\\nexit 0\\n" > "$d/.claude/hooks/demo.sh"; chmod +x "$d/.claude/hooks/demo.sh"'
ok_case "hooks 配下にサブディレクトリ"      'mkdir -p "$d/.claude/hooks/lib.sh"'

# ============================================================================
# §3 workflows: JS 構文 + export const meta + 非決定的 API の禁止
# ============================================================================
ng_case "workflow に JS 構文エラー"         "JS 構文エラー" 'printf "\nconst broken = (\n" >> "$d/.claude/workflows/demo.js"'
ng_case "workflow に export const meta が無い" "'export const meta' が無い" 'printf "const x = 1;\nreturn x;\n" > "$d/.claude/workflows/demo.js"'
ng_case "workflow が Date.now を使う"       "使用禁止" 'printf "\nconst t = Date.now();\n" >> "$d/.claude/workflows/demo.js"'
ng_case "workflow が Math.random を使う"    "使用禁止" 'printf "\nconst r = Math.random();\n" >> "$d/.claude/workflows/demo.js"'
ng_case "workflow が new Date() を使う"     "使用禁止" 'printf "\nconst t = new Date();\n" >> "$d/.claude/workflows/demo.js"'
ng_case "workflow が new Date( ) を使う（空白回避）" "使用禁止" 'printf "\nconst t = new Date( );\n" >> "$d/.claude/workflows/demo.js"'
ng_case "workflow が Date . now を使う（空白回避）"  "使用禁止" 'printf "\nconst t = Date . now();\n" >> "$d/.claude/workflows/demo.js"'
ng_case "workflow が Math . random を使う（空白回避）" "使用禁止" 'printf "\nconst r = Math . random();\n" >> "$d/.claude/workflows/demo.js"'
ok_case "workflow がトップレベル return/await を使う" 'printf "\nawait null;\nreturn 1;\n" >> "$d/.claude/workflows/demo.js"'
ok_case "package.json が type:module でも合格" 'printf "{\"name\":\"f\",\"type\":\"module\"}\n" > "$d/package.json"'
ok_case "固定引数の new Date(0) は許可（決定的）" 'printf "\nconst t = new Date(0);\n" >> "$d/.claude/workflows/demo.js"'
ok_case "newDate() のような紛らわしい識別子は誤検知しない" 'printf "\nconst t = newDate();\nconst u = MathRandom();\n" >> "$d/.claude/workflows/demo.js"'
ok_case "workflows が空ディレクトリ"        'rm -f "$d"/.claude/workflows/*.js'

# ============================================================================
# §4 skills: SKILL.md の存在 + frontmatter(name/description) + 500行未満
# ============================================================================
ng_case "skills に SKILL.md が無い"         "SKILL.md が無い" 'rm "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md に frontmatter が無い"    "frontmatter が無い" 'printf "# no frontmatter\n" > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md の frontmatter に name が無い" "frontmatter に name が無い" 'printf -- "---\ndescription: d\n---\n\nbody\n" > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md の frontmatter に description が無い" "frontmatter に description が無い" 'printf -- "---\nname: d\n---\n\nbody\n" > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md の frontmatter が閉じていない" "終端 --- で閉じていない" 'printf -- "---\nname: d\ndescription: d\n\nbody\n" > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md の name が本文にしか無い" "frontmatter に name が無い" 'printf -- "---\ndescription: d\n---\n\nname: d\n" > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md が空ファイル"             "frontmatter が無い" ': > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md がちょうど500行"          "500行以上" 'skill_file 500 "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md が501行"                  "500行以上" 'skill_file 501 "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md が500行（末尾改行なし）"  "500行以上" 'skill_file_nonl 500 "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md が巨大（20000行）"        "500行以上" 'skill_file 20000 "$d/.claude/skills/demo/SKILL.md"'
ok_case "SKILL.md が499行（上限ちょうど手前）" 'skill_file 499 "$d/.claude/skills/demo/SKILL.md"'
ok_case "SKILL.md が499行（末尾改行なし）"  'skill_file_nonl 499 "$d/.claude/skills/demo/SKILL.md"'
ok_case "SKILL.md の frontmatter が CRLF"   'printf -- "---\r\nname: d\r\ndescription: d\r\n---\r\n\r\nbody\r\n" > "$d/.claude/skills/demo/SKILL.md"'
ng_case "SKILL.md が BOM で始まる（frontmatter 判定不能）" "frontmatter が無い" 'printf "\357\273\277---\nname: d\ndescription: d\n---\n" > "$d/.claude/skills/demo/SKILL.md"'
ok_case "skills にサブディレクトリが無い"   'rm -rf "$d/.claude/skills/demo"'
ng_case "skills の2つ目が SKILL.md 欠落"    "SKILL.md が無い" 'mkdir -p "$d/.claude/skills/other"'

# ============================================================================
# §5 agents: frontmatter(name/description) + model はエイリアスのみ
# ============================================================================
ng_case "agent に frontmatter が無い"       "frontmatter が無い" 'printf "# agent\n" > "$d/.claude/agents/demo.md"'
ng_case "agent の frontmatter に name が無い" "frontmatter に name が無い" 'printf -- "---\ndescription: d\n---\n" > "$d/.claude/agents/demo.md"'
ng_case "agent の frontmatter に description が無い" "frontmatter に description が無い" 'printf -- "---\nname: a\n---\n" > "$d/.claude/agents/demo.md"'
ng_case "agent の frontmatter が閉じていない" "終端 --- で閉じていない" 'printf -- "---\nname: a\ndescription: d\n\nbody\n" > "$d/.claude/agents/demo.md"'
ng_case "agent が空ファイル"                "frontmatter が無い" ': > "$d/.claude/agents/demo.md"'
ng_case "agent の model が番号付き固定ID"   "エイリアス" 'sed -i "s/^model: inherit/model: claude-opus-4-1/" "$d/.claude/agents/demo.md"'
ng_case "agent の model が引用符付き固定ID" "エイリアス" 'sed -i "s/^model: inherit/model: \"claude-sonnet-4-5\"/" "$d/.claude/agents/demo.md"'
ng_case "agent の model が旧世代の日付入りID" "エイリアス" 'sed -i "s/^model: inherit/model: claude-3-5-sonnet-20241022/" "$d/.claude/agents/demo.md"'
ok_case "agent の model が opus"            'sed -i "s/^model: inherit/model: opus/" "$d/.claude/agents/demo.md"'
ok_case "agent の model が sonnet"          'sed -i "s/^model: inherit/model: sonnet/" "$d/.claude/agents/demo.md"'
ok_case "agent の model が haiku"           'sed -i "s/^model: inherit/model: haiku/" "$d/.claude/agents/demo.md"'
ok_case "agent に model 行が無い"           'sed -i "/^model:/d" "$d/.claude/agents/demo.md"'
ok_case "agent の本文に固定IDが書かれているだけ" 'printf "\n本文で claude-opus-4-1 に言及する\n" >> "$d/.claude/agents/demo.md"'
ok_case "agent の frontmatter が CRLF"      'printf -- "---\r\nname: a\r\ndescription: d\r\nmodel: inherit\r\n---\r\n" > "$d/.claude/agents/demo.md"'
ng_case "agents の2つ目が frontmatter 無し" "frontmatter が無い" 'printf "# bare\n" > "$d/.claude/agents/other.md"'

# ============================================================================
# §6 rules: paths スコープ or 無条件ロードの明示
# ============================================================================
ng_case "rule に frontmatter があるのに paths が無い" "paths: が無い" 'printf -- "---\nname: r\n---\n\nbody\n" > "$d/.claude/rules/scoped.md"'
ng_case "rule に frontmatter も unscoped 明示も無い" "無条件ロード" 'printf "just a rule\n" > "$d/.claude/rules/unscoped.md"'
ng_case "rule の frontmatter が閉じていない" "終端 --- で閉じていない" 'printf -- "---\npaths: [\"src/**\"]\n\nbody\n" > "$d/.claude/rules/scoped.md"'
ng_case "rule の paths が本文にしか無い"    "paths: が無い" 'printf -- "---\nname: r\n---\n\npaths: [\"src/**\"]\n" > "$d/.claude/rules/scoped.md"'
ok_case "rule が unscoped マーカーを持つ"   'printf -- "<!-- unscoped -->\n# rule\n" > "$d/.claude/rules/unscoped.md"'
ok_case "rule の frontmatter が CRLF + paths" 'printf -- "---\r\npaths: [\"src/**\"]\r\n---\r\n\r\nbody\r\n" > "$d/.claude/rules/scoped.md"'
ng_case "rule が空ファイル"                 "無条件ロード" ': > "$d/.claude/rules/unscoped.md"'

# ============================================================================
# §7 CLAUDE.md: 存在 + 200行未満
# ============================================================================
ng_case "CLAUDE.md が無い"                  "CLAUDE.md が存在しない" 'rm "$d/CLAUDE.md"'
ng_case "CLAUDE.md がちょうど200行"         "200行以上" 'lines_file 200 "$d/CLAUDE.md"'
ng_case "CLAUDE.md が201行"                 "200行以上" 'lines_file 201 "$d/CLAUDE.md"'
ng_case "CLAUDE.md が200行（末尾改行なし）" "200行以上" 'lines_file_nonl 200 "$d/CLAUDE.md"'
ng_case "CLAUDE.md が巨大（50000行）"       "200行以上" 'lines_file 50000 "$d/CLAUDE.md"'
ok_case "CLAUDE.md が199行（上限ちょうど手前）" 'lines_file 199 "$d/CLAUDE.md"'
ok_case "CLAUDE.md が199行（末尾改行なし）" 'lines_file_nonl 199 "$d/CLAUDE.md"'
ok_case "CLAUDE.md が空ファイル（0行）"     ': > "$d/CLAUDE.md"'
ok_case "CLAUDE.md 以外に巨大な md があっても無関係" 'lines_file 5000 "$d/docs/huge.md"'

# ============================================================================
# §8 ADR: template/README + 連番ファイル名 + index の双方向同期
# ============================================================================
ng_case "docs/adr/template.md が無い"       "template.md が無い" 'rm "$d/docs/adr/template.md"'
ng_case "docs/adr/README.md (index) が無い" "(index) が無い" 'rm "$d/docs/adr/README.md"'
ng_case "ADR ファイル名が kebab-case でない" "NNNN-kebab-case.md 形式" 'mv "$d/docs/adr/0001-demo-decision.md" "$d/docs/adr/0001-Demo_Decision.md"; printf "# idx\n- 0001-Demo_Decision.md\n" > "$d/docs/adr/README.md"'
ng_case "ADR の連番が3桁"                   "NNNN-kebab-case.md 形式" 'mv "$d/docs/adr/0001-demo-decision.md" "$d/docs/adr/001-demo.md"; printf "# idx\n- 001-demo.md\n" > "$d/docs/adr/README.md"'
ng_case "ADR が index に載っていない"       "index を更新する" 'printf "# idx\n" > "$d/docs/adr/README.md"'
ng_case "新しい ADR だけ index 漏れ"        "index を更新する" 'printf "# ADR 0002\n" > "$d/docs/adr/0002-second.md"'
ng_case "index が実在しない ADR を参照"     "実在しない" 'printf "# idx\n- 0001-demo-decision.md\n- 9999-ghost-adr.md\n" > "$d/docs/adr/README.md"'
ng_case "index の記載が綴り違い（. のワイルドカード誤爆）" "index を更新する" 'printf "# idx\n- 0001-demo-decisionXmd\n" > "$d/docs/adr/README.md"'
ok_case "ADR が複数あり index と同期している" 'printf "# ADR 0002\n" > "$d/docs/adr/0002-second-decision.md"; printf "# idx\n- 0001-demo-decision.md\n- 0002-second-decision.md\n" > "$d/docs/adr/README.md"'
ok_case "docs/adr に ADR が1本も無い"       'rm "$d/docs/adr/0001-demo-decision.md"; printf "# idx\n" > "$d/docs/adr/README.md"'
ok_case "index が同じ ADR を複数回参照"     'printf "# idx\n- 0001-demo-decision.md\n- 再掲: 0001-demo-decision.md\n" > "$d/docs/adr/README.md"'

# ============================================================================
# §9 docs/process: プロセス定義の必須ファイル
# ============================================================================
for req in README lifecycle requirements traceability verification ipa-mapping; do
  ng_case "docs/process/$req.md が無い" "docs/process/$req.md が無い" "rm \"\$d/docs/process/$req.md\""
done
for tpl in requirement-spec test-design postmortem traceability-matrix; do
  ng_case "docs/process/templates/$tpl.md が無い" "templates/$tpl.md が無い" "rm \"\$d/docs/process/templates/$tpl.md\""
done
ok_case "docs/process に追加ファイルがあっても良い" 'printf "# extra\n" > "$d/docs/process/extra.md"'

# ============================================================================
# §10 コンパニオンプラグイン（ADR-0008）
# ============================================================================
ng_case "marketplace.json が無い"           "が無い（プラグイン構成の欠落）" 'rm "$d/.claude-plugin/marketplace.json"'
ng_case "plugin.json が無い"                "が無い（プラグイン構成の欠落）" 'rm "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin/hooks/hooks.json が無い"    "が無い（プラグイン構成の欠落）" 'rm "$d/plugin/hooks/hooks.json"'
ng_case "plugin.json が不正な JSON"         "が不正な JSON" 'printf "{\"name\": \"deb-companion\",\n" > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin.json が空ファイル"          "が不正な JSON" ': > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "marketplace.json が空ファイル"     "が不正な JSON" ': > "$d/.claude-plugin/marketplace.json"'
ng_case "hooks.json が BOM 付き"            "が不正な JSON" 'printf "\357\273\277{}\n" > "$d/plugin/hooks/hooks.json"'
ng_case "plugin.json の name が CamelCase"  "kebab-case にする" 'printf "{\"name\": \"DebCompanion\"}\n" > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin.json の name がアンダースコア" "kebab-case にする" 'printf "{\"name\": \"deb_companion\"}\n" > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin.json に name が無い"        "kebab-case にする" 'printf "{\"version\": \"1.0.0\"}\n" > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin.json の name が null"       "kebab-case にする" 'printf "{\"name\": null}\n" > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin.json がトップレベル配列"    "kebab-case にする" 'printf "[{\"name\": \"deb-companion\"}]\n" > "$d/plugin/.claude-plugin/plugin.json"'
ng_case "plugin/skills が無い"              "揃っていない" 'rm -rf "$d/plugin/skills"'
ng_case "plugin/agents が無い"              "揃っていない" 'rm -rf "$d/plugin/agents"'
ng_case "plugin/hooks が無い"               "揃っていない" 'rm -rf "$d/plugin/hooks"'
ok_case "plugin.json の name が数字入り kebab" 'printf "{\"name\": \"deb-companion-2\"}\n" > "$d/plugin/.claude-plugin/plugin.json"'
ok_case "plugin.json に author.name があっても誤爆しない" 'printf "{\"name\": \"deb-companion\", \"author\": {\"name\": \"Some One\"}}\n" > "$d/plugin/.claude-plugin/plugin.json"'
ok_case "plugin ディレクトリが無い（プラグイン任意）" 'rm -rf "$d/plugin"'

# ============================================================================
# フェイルセーフの向き: パーサ欠落・二重バックエンド等価性・ロケール
# ============================================================================
# jq のみ / python3 のみ / どちらも無し の PATH サンドボックスを用意する
# @description PATH サンドボックス用の bin ディレクトリを作る。基本ツールだけを symlink し、
#   追加ツール（jq / python3）の有無で「検証ツールが欠けた環境」を再現する。
# @internal
# @arg $1 string 作成するサンドボックスのディレクトリ名（$work 配下）
# @arg $@ string 追加で symlink するツール名
# @stdout 作成したサンドボックスの絶対パス
mkbin() { # dir, 追加ツール...
  sbx="$work/$1"; rm -rf "$sbx"; mkdir -p "$sbx"
  for t in bash sh awk sed grep sort uniq head tail wc find cat basename dirname tr cut node mktemp rm chmod ls printf env dd od cksum; do
    p=$(command -v "$t" 2>/dev/null); [ -n "$p" ] && ln -sf "$p" "$sbx/$t"
  done
  shift
  for t in "$@"; do p=$(command -v "$t" 2>/dev/null); [ -n "$p" ] && ln -sf "$p" "$sbx/$t"; done
  echo "$sbx"
}
BIN_NONE=$(mkbin bin-none)
BIN_JQ=$(mkbin bin-jq jq)
BIN_PY=$(mkbin bin-py python3)

# @description PATH を絞った環境で validate-foundation.sh を実行し、期待の向き（合格/失敗）に
#   倒れることを検査する。パーサ欠落時に fail-open しないことの固定に使う。
# @internal
# @arg $1 string ケースの説明
# @arg $2 path 実行時の PATH
# @arg $3 int 期待する結果（0=合格 / それ以外=失敗）
# @arg $4 string フィクスチャに適用する変異コード（eval される）
# @set fail int 期待と違えば 1
path_case() { # desc, PATH, 期待exit(0/nonzero), 変異コード
  newfix
  eval "$4"
  run_vf_env "PATH=$2"; ec=$?
  if { [ "$3" = 0 ] && [ "$ec" -eq 0 ]; } || { [ "$3" != 0 ] && [ "$ec" -ne 0 ]; }; then
    pass_ "$1"
  else
    fail_ "$1 (exit=$ec)"
  fi
  rm -rf "$d"
}

path_case "jq/python3 無しでも正しい構成は合格（偽失敗しない）" "$BIN_NONE" 0 ':'
path_case "jq のみでも正しい構成は合格"      "$BIN_JQ" 0 ':'
path_case "python3 のみでも正しい構成は合格" "$BIN_PY" 0 ':'
path_case "jq/python3 無しでも settings.json 欠落は検知（fail-closed）" "$BIN_NONE" 1 'rm "$d/.claude/settings.json"'
path_case "jq/python3 無しでも plugin.json 欠落は検知（fail-closed）"   "$BIN_NONE" 1 'rm "$d/plugin/.claude-plugin/plugin.json"'
path_case "jq/python3 無しでも frontmatter 違反は検知（fail-closed）"   "$BIN_NONE" 1 'printf "# bare\n" > "$d/.claude/agents/demo.md"'
path_case "jq/python3 無しでも行数超過は検知（fail-closed）"           "$BIN_NONE" 1 'lines_file 200 "$d/CLAUDE.md"'

# パーサ不在時の「判定不能」は黙って合格させず、スキップとして明示されること
newfix
run_vf_env "PATH=$BIN_NONE"
if [ "$(grep -c 'JSON 検証ツール無しのため構文検査はスキップ' "$LOG")" -ge 4 ]; then
  pass_ "パーサ不在時は settings.json / plugin JSON のスキップを明示する"
else
  fail_ "パーサ不在時のスキップが黙殺されている（判定不能が不可視）"
fi
rm -rf "$d"

# 二重バックエンド等価性: 同じ入力に対し jq 経路と python3 経路の verdict が一致すること
# @description 二重バックエンド等価性の検査。同じ入力に対し jq 経路と python3 経路の verdict が
#   一致すること（インストール済みツール次第でゲート結果が変わらないこと）を固定する。
# @internal
# @arg $1 string ケースの説明
# @arg $2 string JSON を書き換える変異コード（eval される）
# @set fail int 経路間で verdict が食い違えば 1
equiv_case() { # desc, JSON を書く変異コード
  newfix
  eval "$2"
  run_vf_env "PATH=$BIN_JQ"; ec_jq=$?
  run_vf_env "PATH=$BIN_PY"; ec_py=$?
  if { [ "$ec_jq" -eq 0 ] && [ "$ec_py" -eq 0 ]; } || { [ "$ec_jq" -ne 0 ] && [ "$ec_py" -ne 0 ]; }; then
    pass_ "jq/python3 で同一 verdict: $1"
  else
    fail_ "jq/python3 で verdict が食い違う: $1 (jq=$ec_jq python3=$ec_py)"
  fi
  rm -rf "$d"
}
equiv_case "正常な settings.json"       ':'
equiv_case "空の settings.json"         ': > "$d/.claude/settings.json"'
equiv_case "空白のみの settings.json"   'printf "  \n" > "$d/.claude/settings.json"'
equiv_case "複数ドキュメント連結"       'printf "{\"a\":1} {\"b\":2}\n" > "$d/.claude/settings.json"'
equiv_case "BOM 付き settings.json"     'printf "\357\273\277{}\n" > "$d/.claude/settings.json"'
equiv_case "壊れた settings.json"       'printf "{oops\n" > "$d/.claude/settings.json"'
equiv_case "トップレベル null の settings.json" 'printf "null\n" > "$d/.claude/settings.json"'
equiv_case "plugin.json の name 欠落"   'printf "{\"version\":\"1\"}\n" > "$d/plugin/.claude-plugin/plugin.json"'
equiv_case "plugin.json がトップレベル配列" 'printf "[1,2]\n" > "$d/plugin/.claude-plugin/plugin.json"'
equiv_case "plugin.json が空"           ': > "$d/plugin/.claude-plugin/plugin.json"'

# ロケール非依存: LC_ALL を変えても verdict が変わらないこと
locales="C"
for L in C.utf8 C.UTF-8 ja_JP.utf8 ja_JP.UTF-8; do
  locale -a 2>/dev/null | grep -qx "$L" && locales="$locales $L"
done
# @description ロケール非依存の検査。利用可能な全ロケールで実行し、verdict が互いに一致し、
#   かつ期待どおりであることを固定する（ロケール依存の判定を排除する）。
# @internal
# @arg $1 string ケースの説明
# @arg $2 int 期待する結果（0=合格 / 1=失敗）
# @arg $3 string フィクスチャに適用する変異コード（eval される）
# @set fail int ロケール間で食い違う、または期待と違えば 1
locale_case() { # desc, 期待exit, 変異コード
  newfix
  eval "$3"
  agree=1; first=""
  for L in $locales; do
    run_vf_env "LC_ALL=$L"; e=$?
    [ "$e" -ne 0 ] && e=1
    [ -z "$first" ] && first=$e
    [ "$e" = "$first" ] || agree=0
    [ "$e" = "$2" ] || agree=0
  done
  if [ "$agree" = 1 ]; then pass_ "ロケール非依存($locales): $1"; else fail_ "ロケール依存の判定: $1"; fi
  rm -rf "$d"
}
locale_case "正しい構成"                  0 ':'
locale_case "CLAUDE.md 200行"             1 'lines_file 200 "$d/CLAUDE.md"'
locale_case "SKILL.md 500行"              1 'skill_file 500 "$d/.claude/skills/demo/SKILL.md"'
locale_case "BOM 付き settings.json"      1 'printf "\357\273\277{}\n" > "$d/.claude/settings.json"'
locale_case "CRLF frontmatter の agent"   0 'printf -- "---\r\nname: a\r\ndescription: d\r\n---\r\n" > "$d/.claude/agents/demo.md"'
locale_case "不正 UTF-8 を含む agent（frontmatter は正しい）" 0 'printf -- "---\nname: a\ndescription: d\n---\n\n\377\376 broken bytes\n" > "$d/.claude/agents/demo.md"'
locale_case "不正 UTF-8 を含む agent（name 欠落）" 1 'printf -- "---\ndescription: d\n---\n\n\377\376\n" > "$d/.claude/agents/demo.md"'
locale_case "不正 UTF-8 を含む CLAUDE.md が200行" 1 'awk "BEGIN{ for (i = 0; i < 199; i++) print \"x\"; printf \"\377\376\n\" }" > "$d/CLAUDE.md"'
locale_case "日本語ファイル名の rule（unscoped 明示あり）" 0 'printf -- "<!-- unscoped -->\n本文\n" > "$d/.claude/rules/規約.md"'
locale_case "日本語ファイル名の rule（明示なし）" 1 'printf -- "本文だけ\n" > "$d/.claude/rules/規約.md"'

# 複数の違反が同時にあっても、すべて報告して落ちること（最初の1件で打ち切らない）
newfix
rm "$d/CLAUDE.md"
rm "$d/.claude/settings.json"
printf "# bare\n" > "$d/.claude/agents/demo.md"
run_vf; ec=$?
ngs=$(grep -c '^NG' "$LOG")
if [ "$ec" -ne 0 ] && [ "$ngs" -ge 3 ]; then pass_ "違反が複数あるとき全件報告して落ちる（NG=$ngs）"
else fail_ "複数違反の報告が不足（exit=$ec NG=$ngs）"; fi
rm -rf "$d"

# 合格時に「すべて合格」を、失敗時に「失敗」を出す（出力契約）
newfix
run_vf
if grep -q 'validate-foundation: すべて合格' "$LOG"; then pass_ "合格時の出力契約"; else fail_ "合格時の出力契約が壊れている"; fi
rm "$d/CLAUDE.md"
run_vf
if [ $? -ne 0 ] && grep -q 'validate-foundation: 失敗' "$LOG"; then pass_ "失敗時の出力契約"; else fail_ "失敗時の出力契約が壊れている"; fi
rm -rf "$d"

echo ""
echo "アサーション: $count 件"
if [ "$fail" -ne 0 ]; then echo "test-validate-foundation: 失敗" >&2; exit 1; fi
echo "test-validate-foundation: すべて合格"
