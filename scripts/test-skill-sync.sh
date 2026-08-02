#!/usr/bin/env bash
# @file scripts/test-skill-sync.sh
# @brief check-skill-sync.sh の動作テスト（一時フィクスチャで正常系・異常系を検証）。
# @description
#   check-skill-sync.sh の動作テスト。一時フィクスチャで正常系・異常系を検証する。
#   check.sh から呼ばれる。判定ロジックを変えたら再発防止ケースを追加すること。
# @exitcode 0 全ケース合格
# @exitcode 1 いずれかのケースが不合格
# @stdout ケースごとの PASS 行
# @stderr 不合格ケースの FAIL 行
set -u

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

# @description 一時ディレクトリにフィクスチャを組み立て、その中で check-skill-sync.sh を実行する。
#   check-skill-sync.sh は $0/.. へ cd するため、scripts/ を1階層下に置いてフィクスチャのルートを指させる。
# @internal
# @arg $1 string フィクスチャを構築する関数名（フィクスチャのルートで実行される）
# @arg $2 string ケース名（一時ディレクトリ名に使う）
# @exitcode * check-skill-sync.sh の終了コードをそのまま返す（0=合格 / 1=失敗）
run_in_fixture() { # $1=フィクスチャ構築関数 $2=ケース名
  local dir="$work/$2"
  mkdir -p "$dir/scripts"
  cp scripts/check-skill-sync.sh "$dir/scripts/"
  ( cd "$dir" && "$1" && bash "$dir/scripts/check-skill-sync.sh" >/dev/null 2>&1 )
}

# @description 最小の CLAUDE.md（スキル表・エージェント表）を書く。
# @internal
# @arg $1 string 表に載せるスキル名（空白区切り）
# @arg $2 string 表に載せるエージェント名（空白区切り）
write_claude() {
  {
    echo "# test"
    echo "## スキル（\`/name\` で明示起動）"
    echo "| コマンド | 用途 |"
    echo "|---|---|"
    for s in $1; do echo "| \`/$s\` | 説明 |"; done
    echo "## エージェント"
    echo "| エージェント | 権限 | 役割 |"
    echo "|---|---|---|"
    for a in $2; do echo "| $a | 読み書き | 役割 |"; done
    echo "## 次のセクション"
    echo "本文。"
  } > CLAUDE.md
}
# @description 実体スキル（.claude/skills/<name>/SKILL.md）を1件作る。
# @internal
# @arg $1 string スキル名
mk_skill()  { mkdir -p ".claude/skills/$1"; echo "---"$'\n'"name: $1"$'\n'"description: d"$'\n'"---" > ".claude/skills/$1/SKILL.md"; }
# @description 実体エージェント（.claude/agents/<name>.md）を1件作る。
# @internal
# @arg $1 string エージェント名
mk_agent()  { mkdir -p .claude/agents; printf -- '---\nname: %s\ndescription: d\n---\n' "$1" > ".claude/agents/$1.md"; }

# @description ケースA: スキル・エージェントとも一覧と実体が一致 → 合格
caseA() {
  write_claude "round adr" "code-reviewer doc-auditor"
  mk_skill round; mk_skill adr; mk_agent code-reviewer; mk_agent doc-auditor
}
run_in_fixture caseA A; [ $? -eq 0 ] && pass "一致→合格" || bad "一致→合格"

# @description ケースB: 実体スキルが CLAUDE.md 一覧に無い → 失敗
caseB() {
  write_claude "round" "code-reviewer"
  mk_skill round; mk_skill adr; mk_agent code-reviewer   # adr が一覧漏れ
}
run_in_fixture caseB B; [ $? -eq 1 ] && pass "スキル一覧漏れ→失敗" || bad "スキル一覧漏れ→失敗"

# @description ケースC: CLAUDE.md 一覧のスキルに実体が無い → 失敗
caseC() {
  write_claude "round adr fix" "code-reviewer"
  mk_skill round; mk_skill adr; mk_agent code-reviewer   # fix の実体が無い
}
run_in_fixture caseC C; [ $? -eq 1 ] && pass "スキル幽霊(実体なし)→失敗" || bad "スキル幽霊(実体なし)→失敗"

# @description ケースD: 実体エージェントが CLAUDE.md 一覧に無い → 失敗
caseD() {
  write_claude "round" "code-reviewer"
  mk_skill round; mk_agent code-reviewer; mk_agent implementer   # implementer が一覧漏れ
}
run_in_fixture caseD D; [ $? -eq 1 ] && pass "エージェント一覧漏れ→失敗" || bad "エージェント一覧漏れ→失敗"

# @description ケースE(回帰): 別セクションの表（例: ワークフロー）の名前をエージェントと誤認しない → 合格
caseE() {
  write_claude "round" "code-reviewer"
  mk_skill round; mk_agent code-reviewer
  # エージェント表の後ろに、bare name のワークフロー表を足す（誤検知しないこと）
  {
    cat CLAUDE.md
    echo "## ワークフロー"
    echo "| ワークフロー | 用途 |"
    echo "|---|---|"
    echo "| understand | 調査 |"
    echo "| bug-hunt | 探索 |"
  } > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
}
run_in_fixture caseE E; [ $? -eq 0 ] && pass "他セクションの表を誤認しない→合格" || bad "他セクションの表を誤認しない→合格"

# @description ケースF(回帰): 実体スキルの行が無いのに、別行の説明列に `/name` が混じると
#   「宣言済み」と誤認してドリフトを見逃す（1列目のみ対象にする修正の回帰）→ 失敗
caseF() {
  write_claude "round" "code-reviewer"
  mk_skill round; mk_skill ghost; mk_agent code-reviewer   # ghost は実体だけ・表に行なし
  # round の説明列に /ghost を混ぜる（行全体を対象にすると ghost を宣言済みと誤認する）
  sed -i 's#| `/round` | 説明 |#| `/round` | ghost は `/ghost` と併用する説明 |#' CLAUDE.md
}
run_in_fixture caseF F; [ $? -eq 1 ] && pass "説明列の/nameを宣言と誤認しない(drift検出)" || bad "説明列の/nameを宣言と誤認しない(drift検出)"

# --- 網羅ケース群（Round 9 / #35）--------------------------------------------
# @description フィクスチャを実行し、終了コードが期待どおりかを検証する共通ヘルパ。
# @internal
# @arg $1 string フィクスチャ構築関数名
# @arg $2 string ケース名（一時ディレクトリ名）
# @arg $3 int 期待する終了コード（0=合格 / 1=失敗）
# @arg $4 string ケースの説明
# @set fail int 不一致なら 1
expect() { # $1=構築関数 $2=ケース名 $3=期待exit $4=説明
  run_in_fixture "$1" "$2"; local rc=$?
  if [ "$rc" -eq "$3" ]; then pass "$4"; else bad "$4（期待 exit=$3 / 実際 exit=$rc）"; fi
}
# @description run_in_fixture の、出力（stdout+stderr）を取り出す版。メッセージ内容の検査に使う。
# @internal
# @arg $1 string フィクスチャ構築関数名
# @arg $2 string ケース名（一時ディレクトリ名）
# @stdout check-skill-sync.sh の stdout と stderr を結合したもの
capture() { # $1=構築関数 $2=ケース名
  local dir="$work/$2"
  mkdir -p "$dir/scripts"
  cp scripts/check-skill-sync.sh "$dir/scripts/"
  ( cd "$dir" && "$1" >/dev/null 2>&1 && bash "$dir/scripts/check-skill-sync.sh" 2>&1 )
}
# @description 出力が期待の部分文字列を含むことを表明する（メッセージ契約の検査）。
# @internal
# @arg $1 string 実際の出力
# @arg $2 string 含むべき部分文字列
# @arg $3 string ケースの説明
# @set fail int 含まなければ 1
has() { # $1=出力 $2=期待部分文字列 $3=説明
  case "$1" in *"$2"*) pass "$3" ;; *) bad "$3（出力に '$2' が無い）" ;; esac
}

# === 1. 表の書式ゆらぎ（誤検知しないこと） ===
# @description セル前後に余分な空白・タブがあっても1列目を読める
c_ws() {
  mk_skill round; mk_agent code-reviewer
  {
    printf '# t\n## スキル（`/name` で明示起動）\n| コマンド | 用途 |\n|---|---|\n'
    printf '|   \t `/round` \t   | 　説明　 |\n'
    printf '## エージェント\n| エージェント | 権限 |\n|---|---|\n'
    printf '|  \t code-reviewer \t  | 読み取り |\n'
  } > CLAUDE.md
}
expect c_ws ws 0 "セル前後の余分な空白・タブ→誤検知しない"
# @description 行末のパイプが無い表行でも1列目を読める
c_noeolpipe() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド | 用途 |\n|---|---|\n| `/round` | 説明\n## エージェント\n| エージェント |\n|---|\n| code-reviewer | 役割\n' > CLAUDE.md
}
expect c_noeolpipe noeolpipe 0 "行末パイプなしの表行→1列目を読める"
# @description 1列目がリンク記法でもコマンド名を読める
c_link() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド | 用途 |\n|---|---|\n| [`/round`](.claude/skills/round/SKILL.md) | 説明 |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_link link 0 "1列目のリンク記法→コマンド名を読める"
# @description 区切り行（|---|---|）を宣言と誤認しない
c_sep_only() {
  mkdir -p .claude/skills .claude/agents
  printf '# t\n## スキル\n| コマンド | 用途 |\n|---|---|\n## エージェント\n| エージェント |\n|---|\n## 他\n' > CLAUDE.md
}
expect c_sep_only sep_only 0 "区切り行だけ→宣言0件で合格"
# @description 全角パイプの行は表行と認めない＝宣言漏れとして失敗する（判定不能は安全側）
c_fullwidth_pipe() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n｜ `/round` ｜ 説明 ｜\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_fullwidth_pipe fullwidth_pipe 1 "全角パイプ行→宣言と認めず失敗(fail-closed)"
# @description 説明列に他スキル名の `/name` があっても、正しく同期していれば合格（過剰検知しない）
c_desc_mention_ok() {
  mk_skill round; mk_skill adr; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド | 用途 |\n|---|---|\n| `/round` | `/adr` と併用する |\n| `/adr` | 記録 |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_desc_mention_ok desc_mention_ok 0 "説明列の他スキル名→過剰検知しない"
# @description エージェント表の説明列に別エージェント名があっても宣言と誤認しない（実体漏れを見逃さない）
c_agent_desc_mention() {
  mk_skill round; mk_agent code-reviewer; mk_agent implementer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## エージェント\n| エージェント | 役割 |\n|---|---|\n| code-reviewer | implementer の差分を見る |\n' > CLAUDE.md
}
expect c_agent_desc_mention agent_desc_mention 1 "説明列のエージェント名→宣言と誤認しない(drift検出)"

# === 2. セクション境界 ===
# @description (回帰) スキル節のコードブロック内の表を宣言と誤認しない（幽霊スキルで偽赤にしない）
c_fence_skill() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド | 用途 |\n|---|---|\n| `/round` | 説明 |\n\n```\n| `/example` | 書式例 |\n```\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_fence_skill fence_skill 0 "スキル節のコードブロック内の表を拾わない"
# @description (回帰) エージェント節のコードブロック内の表も拾わない
c_fence_agent() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n\n~~~\n| sample-agent | 書式例 |\n~~~\n' > CLAUDE.md
}
expect c_fence_agent fence_agent 0 "エージェント節の ~~~ ブロック内の表を拾わない"
# @description フェンスで実在スキルの行を隠すと宣言0件になり失敗する（fail-closed は維持）
c_fence_hides() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n```\n| `/round` | 説明 |\n```\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_fence_hides fence_hides 1 "実在スキル行をフェンスで隠す→宣言と認めず失敗"
# @description (回帰) 見出しの部分一致（## スキルの書き方）の表を宣言と誤認しない
c_partial_heading() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n## スキルの書き方\n| 例 | 説明 |\n|---|---|\n| `/sample` | 例 |\n' > CLAUDE.md
}
expect c_partial_heading partial_heading 0 "見出しの部分一致(## スキルの書き方)を拾わない"
# @description エージェント側も同様（## エージェントの追加手順）
c_partial_heading_agent() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n## エージェントの追加手順\n| sample-agent | 例 |\n|---|---|\n' > CLAUDE.md
}
expect c_partial_heading_agent partial_heading_agent 0 "見出しの部分一致(## エージェントの追加手順)を拾わない"
# @description 節の順序が逆（エージェントが先）でも判定できる
c_order_swapped() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## 他\n' > CLAUDE.md
}
expect c_order_swapped order_swapped 0 "節の順序が逆でも判定できる"
# @description スキル節そのものが無い＋実体あり → 失敗
c_no_skill_section() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_no_skill_section no_skill_section 1 "スキル節が無い＋実体あり→失敗"
# @description エージェント節そのものが無い＋実体あり → 失敗
c_no_agent_section() {
  mk_skill round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n' > CLAUDE.md
}
expect c_no_agent_section no_agent_section 1 "エージェント節が無い＋実体あり→失敗"
# @description 他セクションで `/name` が使われていてもスキル宣言に数えない（実体ありは失敗のまま）
c_other_section_cmd() {
  mk_skill round; mk_skill orchestrate; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n## ワークフロー\n| 起動 | 用途 |\n|---|---|\n| `/orchestrate` | 実行 |\n' > CLAUDE.md
}
expect c_other_section_cmd other_section_cmd 1 "他セクションの /name を宣言に数えない(drift検出)"

# === 3. 実体側の数え方 ===
# @description スキルもエージェントも0件で表も空 → 合格
c_zero() {
  mkdir -p .claude/skills .claude/agents
  write_claude "" ""
}
expect c_zero zero 0 "スキル・エージェント0件→合格"
# @description 実体0件なのに一覧にある → 幽霊として失敗
c_zero_but_listed() {
  mkdir -p .claude
  write_claude "round" "code-reviewer"
}
expect c_zero_but_listed zero_but_listed 1 "実体0件＋一覧あり→幽霊で失敗"
# @description 大量（30件）でも一致すれば合格
c_many() {
  local names="" i
  for i in $(seq 1 30); do names="$names skill-$i"; done
  write_claude "$names" "code-reviewer"
  for i in $(seq 1 30); do mk_skill "skill-$i"; done
  mk_agent code-reviewer
}
expect c_many many 0 "スキル30件が一致→合格"
# @description 大量のうち1件だけ一覧漏れ → 失敗
c_many_missing() {
  local names="" i
  for i in $(seq 1 29); do names="$names skill-$i"; done
  write_claude "$names" "code-reviewer"
  for i in $(seq 1 30); do mk_skill "skill-$i"; done
  mk_agent code-reviewer
}
expect c_many_missing many_missing 1 "30件中1件の一覧漏れ→失敗"
# @description 日本語名スキルは命名規約外＝宣言として読めず失敗する（黙って合格にしない）
c_jp_name() {
  mk_skill 日本語; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/日本語` |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_jp_name jp_name 1 "日本語名スキル→規約外として失敗"
# @description 大文字を含むスキル名も規約外として失敗
c_upper_name() {
  mk_skill Round; mk_agent code-reviewer
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/Round` |\n## エージェント\n| エージェント |\n|---|\n| code-reviewer |\n' > CLAUDE.md
}
expect c_upper_name upper_name 1 "大文字を含むスキル名→規約外として失敗"
# @description アンダースコアを含むエージェント名も規約外として失敗
c_underscore_agent() {
  mk_skill round; mk_agent test_agent
  printf '# t\n## スキル\n| コマンド |\n|---|\n| `/round` |\n## エージェント\n| エージェント |\n|---|\n| test_agent |\n' > CLAUDE.md
}
expect c_underscore_agent underscore_agent 1 "アンダースコア入りエージェント名→規約外として失敗"
# @description SKILL.md の無いディレクトリは実体に数えない
c_dir_without_md() {
  mkdir -p .claude/skills/half
  mk_skill round; mk_agent code-reviewer
  write_claude "round" "code-reviewer"
}
expect c_dir_without_md dir_without_md 0 "SKILL.md の無いディレクトリ→実体に数えない"
# @description .claude/agents の非エージェント .md も実体として数える（見落とさない側に倒す）
c_agents_readme() {
  mk_skill round; mk_agent code-reviewer
  printf '案内\n' > .claude/agents/README.md
  write_claude "round" "code-reviewer"
}
expect c_agents_readme agents_readme 1 ".claude/agents の余分な .md→実体として検出(fail-closed)"
# @description スキルは一致・エージェントだけ不一致 → 失敗（両方検査される）
c_agent_only_drift() {
  mk_skill round; mk_agent code-reviewer
  write_claude "round" "code-reviewer doc-auditor"
}
expect c_agent_only_drift agent_only_drift 1 "スキル一致・エージェント幽霊→失敗"
# @description CLAUDE.md が無い → 失敗
c_no_claude() { mkdir -p .claude/skills; }
expect c_no_claude no_claude 1 "CLAUDE.md が無い→失敗"

# === 4. メッセージ ===
out=$(capture caseB msgB)
has "$out" "スキル 'adr'" "一覧漏れスキル名をメッセージに出す"
has "$out" "実体があるが" "一覧漏れの向きをメッセージで区別する"
out=$(capture caseC msgC)
has "$out" "実体が無い" "幽霊エントリの向きをメッセージで区別する"
out=$(capture caseA msgA)
has "$out" "スキル 2 件 / エージェント 2 件" "合格メッセージに件数を出す"

# --- awk 実装間の等価性（インストール済み awk 次第でゲート結果が変わらないこと） ---
# 回帰: 見出しパターンを `awk -v` で渡し、かつ値に `\(` を含めていたため、未定義エスケープの
# 扱いが実装依存になっていた（mawk/nawk はバックスラッシュを残すが original-awk(BWK) は剥がし、
# `^## 名前(` という不正な正規表現で致命エラー → セクションが丸ごと空 → 宣言0件）。
# ローカル(mawk)は緑・CI は赤という非決定論になったため、全実装で同一 verdict を固定する。
# 参照: .claude/rules/tdd.md「二重バックエンド等価性」/ 気づきカード #26
awk_impls=""
for a in awk mawk nawk original-awk gawk busybox; do
  command -v "$a" >/dev/null 2>&1 && awk_impls="$awk_impls $a"
done

# @description awk 実装間の等価性検査。PATH の先頭に各 awk 実装を「awk」という名前で差し込み、
#   どの実装でも同一 verdict になること（インストール済み awk 次第でゲート結果が変わらないこと）を固定する。
# @internal
# @arg $1 string ケース名（一時ディレクトリ名にも使う）
# @arg $2 string フィクスチャ構築関数名
# @arg $3 int 期待する終了コード（0=合格 / 1=失敗）
# @set fail int いずれかの実装で期待と違えば 1
equiv_case() { # $1=ケース名 $2=フィクスチャ構築関数 $3=期待exit
  local name="$1" build="$2" want="$3" dir="$work/awkeq-$1" a bin got base=""
  mkdir -p "$dir/scripts" "$dir/bin"
  cp scripts/check-skill-sync.sh "$dir/scripts/"
  ( cd "$dir" && "$build" ) >/dev/null 2>&1
  for a in $awk_impls; do
    [ "$a" = "busybox" ] && continue          # busybox awk は applet 経由なので個別に扱わない
    bin=$(command -v "$a") || continue
    # PATH の先頭に「awk」という名前で各実装を差し込み、スクリプトが呼ぶ awk を差し替える
    ln -sf "$bin" "$dir/bin/awk"
    ( cd "$dir" && PATH="$dir/bin:$PATH" bash "$dir/scripts/check-skill-sync.sh" >/dev/null 2>&1 )
    got=$?
    if [ "$got" != "$want" ]; then
      bad "awk等価性[$a]: $name（期待 exit=$want / 実際 exit=$got）"
      return
    fi
    [ -z "$base" ] && base="$got"
  done
  pass "awk等価性: $name（${awk_impls# } で同一 verdict exit=$want）"
}

equiv_case "一致→合格"     caseA 0
equiv_case "一覧漏れ→失敗" caseB 1
equiv_case "幽霊→失敗"     caseC 1

echo ""
if [ "$fail" -ne 0 ]; then
  echo "test-skill-sync: 失敗" >&2
  exit 1
fi
echo "test-skill-sync: すべて合格"
