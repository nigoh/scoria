#!/usr/bin/env bash
# @file scripts/test-traceability.sh
# @brief check-traceability.sh の動作テスト（一時フィクスチャで正常系・異常系を検証）。
# @description
#   check-traceability.sh の動作テスト。一時フィクスチャで正常系・異常系を検証する。
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

# フィクスチャ用に一時的な要件ディレクトリを使う（本物の docs/requirements は触らない）
# check-traceability.sh は cwd 基準で docs/requirements を見るため、隔離コピーで実行する
# @description 一時ディレクトリにフィクスチャを組み立て、その中で check-traceability.sh を実行する。
#   本物の docs/requirements は触らない（実リポジトリ非依存・決定論）。
# @internal
# @arg $1 string フィクスチャを構築する関数名（フィクスチャのルートで実行される）
# @arg $2 string ケース名（一時ディレクトリ名に使う）
# @exitcode * check-traceability.sh の終了コードをそのまま返す（0=合格 / 1=失敗）
run_in_fixture() {
  # $1 = フィクスチャ構築関数名, $2 = ケース名
  # check-traceability.sh は $0/.. へ cd するため、scripts/ を1階層下に置いて
  # フィクスチャのルートを正しく指させる（隔離）。
  local dir="$work/$2"
  mkdir -p "$dir/scripts"
  cp scripts/check-traceability.sh "$dir/scripts/"
  ( cd "$dir" && "$1" && bash "$dir/scripts/check-traceability.sh" >/dev/null 2>&1 )
}

# 要件は「宣言行（見出し ### REQ-…: または表の行）」で宣言し、テストは要件ツリー外に置く。

# @description ケースA: 要件ディレクトリ自体が無い → 合格（対象なし）
caseA() { :; }
run_in_fixture caseA A; [ $? -eq 0 ] && pass "要件なし→合格" || bad "要件なし→合格"

# @description ケースB: 要件宣言あり・対応テストなし → 失敗
caseB() {
  mkdir -p docs/requirements
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n' > docs/requirements/r.md
}
run_in_fixture caseB B; [ $? -eq 1 ] && pass "被覆なし→失敗" || bad "被覆なし→失敗"

# @description ケースC: 要件宣言あり・対応テストは要件ツリー外・受入基準あり → 合格
caseC() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n' > docs/requirements/r.md
  printf 'test\n// Verifies: REQ-FIX-001\n' > src/r.test.js
}
run_in_fixture caseC C; [ $? -eq 0 ] && pass "被覆あり(ツリー外)→合格" || bad "被覆あり(ツリー外)→合格"

# @description ケースD: 受入基準セクションが無い → 失敗
caseD() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-002: 基準なし\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-002\n' > src/r.test.js
}
run_in_fixture caseD D; [ $? -eq 1 ] && pass "受入基準なし→失敗" || bad "受入基準なし→失敗"

# @description ケースE(回帰): 散文中の ID 言及は「幻の要件」にしない（宣言でないので被覆不要）→ 合格
caseE() {
  mkdir -p docs/requirements
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n過去の REQ-OLD-999 は廃止した。\n' \
    > docs/requirements/r.md
  mkdir -p src; printf '// Verifies: REQ-FIX-001\n' > src/r.test.js
}
run_in_fixture caseE E; [ $? -eq 0 ] && pass "散文の ID 言及→幻要件にしない" || bad "散文の ID 言及→幻要件にしない"

# @description ケースF(回帰): 自己参照（要件ツリー内の Verifies）は被覆と見なさない → 失敗
caseF() {
  mkdir -p docs/requirements
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n<!-- Verifies: REQ-FIX-001 -->\n' \
    > docs/requirements/r.md
}
run_in_fixture caseF F; [ $? -eq 1 ] && pass "自己参照→被覆と見なさない" || bad "自己参照→被覆と見なさない"

# @description ケースG(回帰): 要件宣言のない index/README は受入基準チェックの対象外 → 合格
caseG() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n' > docs/requirements/r.md
  printf '# 要件一覧\nこれは索引ファイル。\n' > docs/requirements/README.md
  printf '// Verifies: REQ-FIX-001\n' > src/r.test.js
}
run_in_fixture caseG G; [ $? -eq 0 ] && pass "宣言なしREADME→受入基準対象外" || bad "宣言なしREADME→受入基準対象外"

# @description ケースH(回帰): 宣言行に別IDの Verifies が同居しても、宣言側IDが発行済みになる → 被覆なしで失敗
caseH() {
  mkdir -p docs/requirements src
  printf '### REQ-EDGE-001: 例 (Verifies: REQ-OTHER-999)\n## 受入基準\n- Given/When/Then\n' \
    > docs/requirements/r.md
}
run_in_fixture caseH H; [ $? -eq 1 ] && pass "宣言行のVerifies同居→宣言側を発行ID化" || bad "宣言行のVerifies同居→宣言側を発行ID化"

# @description ケースI(回帰): 不正形式ID（4桁）は形式エラーで失敗する（黙って握り潰さない）
caseI() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-1234: 4桁は不正\n## 受入基準\n- Given/When/Then\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-1234\n' > src/r.test.js
}
run_in_fixture caseI I; [ $? -eq 1 ] && pass "不正形式ID(4桁)→形式エラーで失敗" || bad "不正形式ID(4桁)→形式エラーで失敗"

# @description ケースJ(回帰): 4桁ID への Verifies は3桁要件の被覆にならない（右端非アンカーの誤カウント）→ 失敗
caseJ() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-0012\n' > src/r.test.js
}
run_in_fixture caseJ J; [ $? -eq 1 ] && pass "4桁Verifiesは3桁要件を被覆しない" || bad "4桁Verifiesは3桁要件を被覆しない"

# @description ケースK(回帰): コードフェンス内の見出し ### REQ-...: は実在要件として発行しない → 合格
caseK() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n\n```\n### REQ-EXAMPLE-999: 説明用の例\n```\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-001\n' > src/r.test.js
}
run_in_fixture caseK K; [ $? -eq 0 ] && pass "フェンス内の要件見出しは無視" || bad "フェンス内の要件見出しは無視"

# @description ケースL(回帰): 複数ファイル一括処理でフェンス状態が漏れない（閉じ忘れが後続ファイルの要件を消さない）
#   a.md に閉じ忘れフェンス、b.md に REQ-BBB-002(被覆なし)。漏れがあると BBB が消え合格してしまう→失敗であるべき
caseL() {
  mkdir -p docs/requirements src
  printf '### REQ-AAA-001: a\n## 受入基準\n- G/W/T\n```\n閉じ忘れ\n' > docs/requirements/a.md
  printf '### REQ-BBB-002: b\n## 受入基準\n- G/W/T\n' > docs/requirements/b.md
  printf '// Verifies: REQ-AAA-001\n' > src/t.js   # BBB は被覆しない
}
run_in_fixture caseL L; [ $? -eq 1 ] && pass "クロスファイルでフェンス状態が漏れない" || bad "クロスファイルでフェンス状態が漏れない"

# @description ケースM(回帰): ~~~ フェンス内の要件見出しも無視する
caseM() {
  mkdir -p docs/requirements src
  printf '### REQ-OK-001: x\n## 受入基準\n- G/W/T\n\n~~~\n### REQ-PHANTOM-999: 例\n~~~\n' > docs/requirements/r.md
  printf '// Verifies: REQ-OK-001\n' > src/t.js
}
run_in_fixture caseM M; [ $? -eq 0 ] && pass "~~~ フェンス内の要件見出しは無視" || bad "~~~ フェンス内の要件見出しは無視"

# @description ケースN(回帰): 混在フェンス（``` 外・~~~ 内）で早期クローズせず、内側の例示見出しを無視する
caseN() {
  mkdir -p docs/requirements src
  printf '### REQ-OK-001: x\n## 受入基準\n- G/W/T\n\n```markdown\n### REQ-EX-999: 例\n~~~\n### REQ-PHANTOM-998: 例\n~~~\n```\n' > docs/requirements/r.md
  printf '// Verifies: REQ-OK-001\n' > src/t.js
}
run_in_fixture caseN N; [ $? -eq 0 ] && pass "混在フェンス内の要件見出しは無視" || bad "混在フェンス内の要件見出しは無視"

# @description ケースO(回帰): ツリー外の `requirements` という名のディレクトリにある被覆も数える。
#   除外は basename ではなくパス接頭辞($REQ_DIR)で行う。basename 除外だと src/requirements/ の
#   Verifies が深さ無視で落ち、要件を未被覆と誤判定して gate が偽赤になる → 被覆ありで合格すべき。
caseO() {
  mkdir -p docs/requirements src/requirements
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-001\n' > src/requirements/r.test.js
}
run_in_fixture caseO O; [ $? -eq 0 ] && pass "ツリー外 requirements/ の被覆も数える(basename除外の回帰)" || bad "ツリー外 requirements/ の被覆が落ちる(basename除外)"

# @description ケースP(回帰): $REQ_DIR 直下の自己参照は依然として被覆に数えない（パス接頭辞除外が効く）
caseP() {
  mkdir -p docs/requirements
  printf '### REQ-FIX-001: 例\n## 受入基準\n- Given/When/Then\n<!-- Verifies: REQ-FIX-001 -->\n' \
    > docs/requirements/r.md
}
run_in_fixture caseP P; [ $? -eq 1 ] && pass "要件ツリー直下の自己参照は被覆に数えない(接頭辞除外)" || bad "要件ツリー直下の自己参照が被覆に漏れる"

# --- 網羅ケース群（Round 9 / #35）--------------------------------------------
# 以降は共通ヘルパで書く。$3 は期待終了コード（0=合格, 1=失敗）。
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
# 定型: 被覆なしの1要件を宣言する
# @description 定型フィクスチャ: 被覆なしの1要件（REQ-FIX-001・受入基準あり）を宣言する。
# @internal
decl_req() { mkdir -p docs/requirements src; printf '### REQ-FIX-001: 例\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md; }

# === 1. `Verifies:` の検出形 ===
# @description 空白なし（Verifies:REQ-…）でも被覆と認める
c_nospace() { decl_req; printf '// Verifies:REQ-FIX-001\n' > src/t.js; }
expect c_nospace nospace 0 "Verifies: 直後に空白なし→被覆"
# @description 前後に余分な空白・タブがあっても被覆と認める
c_ws() { decl_req; printf '   \t Verifies:  \t REQ-FIX-001   \n' > src/t.js; }
expect c_ws ws 0 "Verifies: 前後の余分な空白→被覆"
# @description 全角コロン（Verifies：）は被覆と認めない＝判定不能は fail-closed に倒す
c_fullwidth() { decl_req; printf '// Verifies： REQ-FIX-001\n' > src/t.js; }
expect c_fullwidth fullwidth 1 "全角コロンの Verifies：→被覆と認めない(fail-closed)"
# @description 小文字 verifies: も被覆と認めない（表記を1つに固定する）
c_lower() { decl_req; printf '// verifies: REQ-FIX-001\n' > src/t.js; }
expect c_lower lowerverifies 1 "小文字 verifies:→被覆と認めない(fail-closed)"
# @description HTML コメント内の Verifies（要件ツリー外）は被覆
c_comment() { decl_req; printf '<!-- Verifies: REQ-FIX-001 -->\n' > src/t.md; }
expect c_comment comment 0 "コメント内 Verifies(ツリー外)→被覆"
# @description 1行に複数 ID を列挙
c_multi_inline() {
  mkdir -p docs/requirements src
  printf '### REQ-AAA-001: a\n### REQ-BBB-002: b\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
  printf '// Verifies: REQ-AAA-001, REQ-BBB-002\n' > src/t.js
}
expect c_multi_inline multi_inline 0 "1行に複数IDの列挙→どちらも被覆"
# @description 複数行に分けた Verifies
c_multi_line() {
  mkdir -p docs/requirements src
  printf '### REQ-AAA-001: a\n### REQ-BBB-002: b\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
  printf '// Verifies: REQ-AAA-001\n// Verifies: REQ-BBB-002\n' > src/t.js
}
expect c_multi_line multi_line 0 "複数行の Verifies→それぞれ被覆"
# @description 複数要件のうち1つだけ被覆 → 失敗（部分被覆を合格にしない）
c_partial() {
  mkdir -p docs/requirements src
  printf '### REQ-AAA-001: a\n### REQ-BBB-002: b\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
  printf '// Verifies: REQ-AAA-001\n' > src/t.js
}
expect c_partial partial 1 "部分被覆(2件中1件)→失敗"
# @description 表セル内の Verifies も被覆
c_tablecell() { decl_req; printf '| ケース | Verifies: REQ-FIX-001 |\n' > src/t.md; }
expect c_tablecell tablecell 0 "表セル内の Verifies→被覆"
# @description ツリー外ファイルのコードフェンス内 Verifies は被覆に数える（除外はツリーのみ）
c_fenced_ref() { decl_req; printf 'text\n```\nVerifies: REQ-FIX-001\n```\n' > src/doc.md; }
expect c_fenced_ref fenced_ref 0 "ツリー外フェンス内の Verifies→被覆"
# @description 右端の部分一致（REQ-FIX-001X）は被覆にしない
c_suffix() { decl_req; printf '// Verifies: REQ-FIX-001X\n' > src/t.js; }
expect c_suffix suffix 1 "右端が続くトークン(001X)→被覆にしない"
# @description 左端の部分一致（XREQ-FIX-001）は被覆にしない
c_prefix() { decl_req; printf '// Verifies: XREQ-FIX-001\n' > src/t.js; }
expect c_prefix prefix 1 "左端が続くトークン(XREQ-)→被覆にしない"
# @description .git 配下の Verifies は被覆に数えない
c_gitdir() { decl_req; mkdir -p .git; printf 'Verifies: REQ-FIX-001\n' > .git/COMMIT_EDITMSG; }
expect c_gitdir gitdir 1 ".git 配下の Verifies→被覆に数えない"
# @description 隠しディレクトリ（.git 以外）の Verifies は被覆に数える
c_hidden() { decl_req; mkdir -p .config; printf 'Verifies: REQ-FIX-001\n' > .config/t.md; }
expect c_hidden hidden 0 ".git 以外の隠しディレクトリの Verifies→被覆"

# === 2. ID 体系 ===
# @description NFR を表行で宣言し被覆あり
c_nfr_ok() {
  mkdir -p docs/requirements src
  printf '# 非機能\n| ID | 内容 |\n|---|---|\n| NFR-PERF-001 | 速い |\n## 受入基準\n- G/W/T\n' > docs/requirements/n.md
  printf '// Verifies: NFR-PERF-001\n' > src/t.js
}
expect c_nfr_ok nfr_ok 0 "NFR を表行で宣言・被覆あり→合格"
# @description NFR 被覆なし → 失敗
c_nfr_ng() {
  mkdir -p docs/requirements src
  printf '# 非機能\n| ID | 内容 |\n|---|---|\n| NFR-PERF-001 | 速い |\n## 受入基準\n- G/W/T\n' > docs/requirements/n.md
}
expect c_nfr_ng nfr_ng 1 "NFR 被覆なし→失敗"
# @description 連番2桁は形式エラー
c_2digit() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-01: 2桁\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-01\n' > src/t.js
}
expect c_2digit twodigit 1 "連番2桁→形式エラーで失敗"
# @description 領域が小文字は形式エラー
c_lowerarea() {
  mkdir -p docs/requirements src
  printf '### REQ-fix-001: 小文字領域\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
  printf '// Verifies: REQ-fix-001\n' > src/t.js
}
expect c_lowerarea lowerarea 1 "領域が小文字→形式エラーで失敗"
# @description 未知接頭辞（XYZ-/TEST-）は要件 ID として扱わない（過剰検知しない）
c_unknown_prefix() {
  mkdir -p docs/requirements
  printf '### XYZ-FIX-001: 別体系\n### TEST-CASE-001: テストID\n' > docs/requirements/r.md
}
expect c_unknown_prefix unknown_prefix 0 "未知接頭辞(XYZ/TEST)→要件IDにしない"
# @description 同一 ID を2ファイルで重複宣言 → 被覆1つで合格（重複を二重要求しない）
c_dup() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: a\n## 受入基準\n- G/W/T\n' > docs/requirements/a.md
  printf '### REQ-FIX-001: 再掲\n## 受入基準\n- G/W/T\n' > docs/requirements/b.md
  printf '// Verifies: REQ-FIX-001\n' > src/t.js
}
expect c_dup dup 0 "同一IDの重複宣言→被覆1つで合格"
# @description DES-<3桁> 参照だけでは REQ の被覆にならない
c_des_only() { decl_req; printf '// Verifies: DES-001\n' > src/t.js; }
expect c_des_only des_only 1 "DES 参照だけでは REQ を被覆しない"

# === 3. 宣言行の形 ===
# @description 見出しレベル1でも宣言と見なす（被覆なし→失敗）
c_h1() { mkdir -p docs/requirements; printf '# REQ-FIX-001: h1\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md; }
expect c_h1 h1 1 "見出しレベル1の宣言→発行IDとして扱う"
# @description 行頭インデントのある宣言行も見逃さない
c_indent() { mkdir -p docs/requirements; printf '  ### REQ-FIX-001: indent\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md; }
expect c_indent indent 1 "インデントされた宣言行→発行IDとして扱う"
# @description ヘッダのない壊れた表行でも宣言として拾う（被覆なし→失敗）
c_broken_table() { mkdir -p docs/requirements; printf '| REQ-FIX-001 | ヘッダなしの壊れた表\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md; }
expect c_broken_table broken_table 1 "ヘッダなしの壊れた表行→発行IDとして扱う"
# @description 深い階層の要件ファイルも走査対象
c_deep() { mkdir -p docs/requirements/a/b; printf '### REQ-FIX-001: deep\n## 受入基準\n- G/W/T\n' > docs/requirements/a/b/r.md; }
expect c_deep deep 1 "深い階層の要件ファイルも走査する"
# @description .md 以外（.txt）は要件ファイルとして扱わない
c_txt() { mkdir -p docs/requirements; printf '### REQ-FIX-001: txt\n' > docs/requirements/r.txt; }
expect c_txt txt 0 ".md 以外は要件ファイルにしない"
# @description symlink の要件ファイルも辿る（find -L）
c_symlink() {
  mkdir -p docs/requirements real
  printf '### REQ-FIX-001: リンク先\n## 受入基準\n- G/W/T\n' > real/r.md
  ln -s ../../real/r.md docs/requirements/r.md
}
expect c_symlink symlink 1 "symlink の要件ファイルも辿る(見落とさない)"
# @description 要件ツリーのサブディレクトリでの自己参照も被覆に数えない
c_selfref_deep() {
  mkdir -p docs/requirements/sub
  printf '### REQ-FIX-001: x\n## 受入基準\n- G/W/T\n<!-- Verifies: REQ-FIX-001 -->\n' > docs/requirements/sub/r.md
}
expect c_selfref_deep selfref_deep 1 "サブディレクトリの自己参照→被覆に数えない"

# === 4. 受入基準 ===
# @description 英語表記 Acceptance Criteria を認める
c_acc_en() { decl_req; printf '### REQ-FIX-001: x\n## Acceptance Criteria\n- G/W/T\n' > docs/requirements/r.md; printf '// Verifies: REQ-FIX-001\n' > src/t.js; }
expect c_acc_en acc_en 0 "Acceptance Criteria(英語)→受入基準あり"
# @description 小文字表記も認める（-i）
c_acc_lower() { decl_req; printf '### REQ-FIX-001: x\n## acceptance criteria\n- G/W/T\n' > docs/requirements/r.md; printf '// Verifies: REQ-FIX-001\n' > src/t.js; }
expect c_acc_lower acc_lower 0 "acceptance criteria(小文字)→受入基準あり"
# @description 被覆はあるが受入基準が無い → 失敗（片方だけで合格にしない）
c_acc_missing() { mkdir -p docs/requirements src; printf '### REQ-FIX-001: x\n本文のみ\n' > docs/requirements/r.md; printf '// Verifies: REQ-FIX-001\n' > src/t.js; }
expect c_acc_missing acc_missing 1 "被覆ありでも受入基準なし→失敗"

# === 5. 最小構成・破損入力・フェイルセーフの向き ===
# @description 要件ディレクトリが空 → 対象なしで合格（過剰検知しない）
c_emptydir() { mkdir -p docs/requirements; }
expect c_emptydir emptydir 0 "要件ディレクトリが空→合格"
# @description 空ファイルのみ → 合格
c_emptyfile() { mkdir -p docs/requirements; : > docs/requirements/r.md; }
expect c_emptyfile emptyfile 0 "空の要件ファイルのみ→合格"
# @description 宣言のない散文だけ → 合格
c_prose_only() { mkdir -p docs/requirements; printf '# 要件\nまだ ID を発行していない。\n' > docs/requirements/r.md; }
expect c_prose_only prose_only 0 "宣言のない散文だけ→合格"
# @description (回帰) NUL バイト混じりの要件ファイルでも宣言を見落とさない。
#   grep が入力をバイナリ扱いして一致行を捨てると「宣言なし＝合格」に倒れ、未被覆要件が素通りする。
c_nul_decl() {
  mkdir -p docs/requirements
  printf '### REQ-FIX-001: x\n\000\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
}
expect c_nul_decl nul_decl 1 "NULバイト混じり要件でも宣言を見落とさない(fail-open回帰)"
# @description NUL 混じりでも被覆があれば合格（-a 追加が正常系を壊していない）
c_nul_covered() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: x\n\000\n## 受入基準\n- G/W/T\n' > docs/requirements/r.md
  printf '// Verifies: REQ-FIX-001\n' > src/t.js
}
expect c_nul_covered nul_covered 0 "NULバイト混じり要件でも被覆があれば合格"
# @description バイナリファイル中の 'Verifies:' 文字列は被覆に数えない（安全側）
c_nul_ref() { decl_req; printf 'Verifies: REQ-FIX-001\n\000\n' > src/blob.bin; }
expect c_nul_ref nul_ref 1 "バイナリ中の Verifies→被覆に数えない(fail-closed)"
# @description 巨大な要件ファイル（20万行）でも宣言・被覆判定が壊れない
c_huge() {
  mkdir -p docs/requirements src
  { printf '### REQ-FIX-001: 巨大\n## 受入基準\n- G/W/T\n'; seq 1 200000 | sed 's/^/行 /'; } > docs/requirements/r.md
}
expect c_huge huge 1 "巨大な要件ファイルでも未被覆を検出する"
# @description リポジトリのパス・ファイル名に空白があっても壊れない（被覆あり→合格）
c_space_path() {
  mkdir -p docs/requirements src
  printf '### REQ-FIX-001: 空白\n## 受入基準\n- G/W/T\n' > "docs/requirements/my req.md"
  printf '// Verifies: REQ-FIX-001\n' > "src/my test.js"
}
expect c_space_path "sp ace dir" 0 "パス・ファイル名に空白→正しく判定する"

echo ""
if [ "$fail" -ne 0 ]; then
  echo "test-traceability: 失敗" >&2
  exit 1
fi
echo "test-traceability: すべて合格"
