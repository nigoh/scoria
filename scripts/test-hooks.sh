#!/usr/bin/env bash
# @file scripts/test-hooks.sh
# @brief hooks（guard-git / guard-protected / quality-gate / session-start）の動作テスト。
# @description
#   hooks の動作テスト: 擬似ツールコール JSON を各ガードフックに流し、期待どおり
#   ブロック（exit 2）/ 許可（exit 0）されるかを検証する。check.sh から呼ばれる。
#   ガードの判定を変更したら、ここに再発防止ケースを追加すること。
#
#   後半（Round 9・#35）は quality-gate.sh と session-start.sh の契約テスト。実リポジトリの
#   状態に依存させず、すべて mktemp -d の隔離 git リポジトリと偽 check.sh スタブで検証する。
# @exitcode 0 全ケース合格
# @exitcode 1 いずれかのケースが不合格（git 不在によるスキップも不合格として扱う）
# @stdout ケースごとの PASS 行
# @stderr 不合格ケースの FAIL 行
set -u

cd "$(dirname "$0")/.." || exit 1

fail=0
# @description 擬似ツールコール JSON をフックに流し、終了コードが期待どおりかを検証する。
# @internal
# @arg $1 string ケースの説明
# @arg $2 path 実行するフックスクリプト
# @arg $3 string stdin に流すフック JSON
# @arg $4 int 期待する終了コード（2=ブロック / 0=許可）
# @set fail int 不一致なら 1
# @stdout "PASS: 説明"
# @stderr 不一致なら "FAIL: 説明 (want=… got=…)"
t() {
  desc="$1"; hook="$2"; json="$3"; want="$4"
  printf '%s' "$json" | bash "$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (want=$want got=$got)" >&2
    fail=1
  fi
}

G=.claude/hooks/guard-git.sh
P=.claude/hooks/guard-protected.sh

# --- guard-git.sh ---
t "force push をブロック"            "$G" '{"tool_input":{"command":"git push --force origin feature"}}' 2
t "force-with-lease をブロック"      "$G" '{"tool_input":{"command":"git push --force-with-lease origin feature"}}' 2
t "-f をブロック"                    "$G" '{"tool_input":{"command":"git push -f origin feature"}}' 2
t "+refspec をブロック"              "$G" '{"tool_input":{"command":"git push origin +feature"}}' 2
t "+src:dst をブロック"              "$G" '{"tool_input":{"command":"git push origin +feature:main"}}' 2
t "main への push をブロック"        "$G" '{"tool_input":{"command":"git push origin main"}}' 2
t "master への push をブロック"      "$G" '{"tool_input":{"command":"git push origin master"}}' 2
t "refspec 経由の main push をブロック" "$G" '{"tool_input":{"command":"git push origin feature:main"}}' 2
t "HEAD:main をブロック"             "$G" '{"tool_input":{"command":"git push origin HEAD:main"}}' 2
t "リモートブランチ削除 :main をブロック" "$G" '{"tool_input":{"command":"git push origin :main"}}' 2
t "二重スペースの git  push もブロック" "$G" '{"tool_input":{"command":"git  push  --force origin feature"}}' 2
t "チェーン内の push もブロック"     "$G" '{"tool_input":{"command":"git add -A && git push origin main"}}' 2
t "クォートで隠した main もブロック" "$G" '{"tool_input":{"command":"git push origin \"main\""}}' 2
t "git -C 経由の main push もブロック" "$G" '{"tool_input":{"command":"git -C /tmp/x push origin main"}}' 2
t "環境変数接頭辞付きもブロック"     "$G" '{"tool_input":{"command":"GIT_TRACE=1 git push origin main"}}' 2
t "git -c 経由の force もブロック"   "$G" '{"tool_input":{"command":"git -c user.name=x push --force origin feature"}}' 2
t "トピックブランチ push を許可"     "$G" '{"tool_input":{"command":"git push -u origin claude/foo"}}' 0
t "main-backup など前方一致を許可"   "$G" '{"tool_input":{"command":"git push origin main-backup"}}' 0
t "無関係なコマンドを許可"           "$G" '{"tool_input":{"command":"ls -la"}}' 0
t "git pushx を許可（誤検知しない）" "$G" '{"tool_input":{"command":"git pushx origin main"}}' 0
t "echo 内の git push 文言を許可"    "$G" '{"tool_input":{"command":"echo git push failed"}}' 0
t "コミットメッセージ内の文言を許可" "$G" '{"tool_input":{"command":"git commit -m \"docs: explain git push --force policy\""}}' 0
t "空入力を許可（フェイルオープン）" "$G" '{}' 0
# 回帰: クォート値内の空白でトークンが割れて判定が脱線しないこと（GG-1）
t "env値に空白があっても main push をブロック"   "$G" '{"tool_input":{"command":"GIT_SSH_COMMAND=\"ssh -i k\" git push origin main"}}' 2
t "-c 値に空白があっても main push をブロック"   "$G" '{"tool_input":{"command":"git -c core.sshCommand=\"ssh -i k\" push origin main"}}' 2
t "env値に空白があっても force push をブロック"  "$G" '{"tool_input":{"command":"GIT_SSH_COMMAND=\"ssh -i k\" git push --force origin feature"}}' 2
# 回帰: 完全修飾 refs/heads/main と行継続（GG3）
t "完全修飾 HEAD:refs/heads/main をブロック" "$G" '{"tool_input":{"command":"git push origin HEAD:refs/heads/main"}}' 2
t "refs/heads/main 直指定をブロック"        "$G" '{"tool_input":{"command":"git push origin refs/heads/main"}}' 2
t "feature/main（非保護ブランチ）は許可"    "$G" '{"tool_input":{"command":"git push origin feature/main"}}' 0
t "バックスラッシュ行継続を跨ぐ main push をブロック" "$G" '{"tool_input":{"command":"git push origin \\\nmain"}}' 2
# 回帰: 全ブランチ push（--all / --mirror）は push 先や現在ブランチに依らずブロック（GG4）
# （これらは 1b の正規表現でブロックされるため、実リポジトリのカレントブランチに依存せず決定論的）
t "--all push をブロック（トピックブランチ上でも）"   "$G" '{"tool_input":{"command":"git push origin --all"}}' 2
t "--all を push の前に置いてもブロック"              "$G" '{"tool_input":{"command":"git push --all origin"}}' 2
t "--mirror push をブロック"                          "$G" '{"tool_input":{"command":"git push --mirror origin"}}' 2
# 注: `--all-of-them` の誤爆しない検証は「push 先未指定」でカレントブランチ検査(3)へ落ちるため、
#     カレントが保護ブランチだと正しくブロックされる（＝実リポジトリで main 上だと exit 2）。
#     ブランチ非依存に regex の誤爆のみを見るため、下の隔離リポジトリ(feat ブランチ)側で検証する。
# 回帰: 束ねた短縮フラグに紛れた force を弾く（git は -fu を -f -u と解釈する。GG5）
t "束ねた -fu の force をブロック"                     "$G" '{"tool_input":{"command":"git push -fu origin feature"}}' 2
t "束ねた -uf の force をブロック"                     "$G" '{"tool_input":{"command":"git push -uf origin feature"}}' 2
t "束ねた -fq の force をブロック"                     "$G" '{"tool_input":{"command":"git push -fq origin feature"}}' 2
t "f を含まない束ねた短縮フラグは許可"                 "$G" '{"tool_input":{"command":"git push -qu origin claude/foo"}}' 0
# 回帰: 短縮 heads/ 前置の dst は既存 refs/heads/main へ解決されるため弾く（GG6）
t "HEAD:heads/main（短縮dst）をブロック"              "$G" '{"tool_input":{"command":"git push origin HEAD:heads/main"}}' 2
t "heads/master（短縮dst）をブロック"                 "$G" '{"tool_input":{"command":"git push origin heads/master"}}' 2

# --- guard-protected.sh ---
t ".env の編集をブロック"            "$P" '{"tool_input":{"file_path":"/repo/.env"}}' 2
t ".env.local の編集をブロック"      "$P" '{"tool_input":{"file_path":"/repo/.env.local"}}' 2
t ".env.example の編集を許可"        "$P" '{"tool_input":{"file_path":"/repo/.env.example"}}' 0
t ".envrc(direnv) の編集をブロック"  "$P" '{"tool_input":{"file_path":"/repo/.envrc"}}' 2
t "pem の編集をブロック"             "$P" '{"tool_input":{"file_path":"/repo/server.pem"}}' 2
t "ロックファイルの編集をブロック"   "$P" '{"tool_input":{"file_path":"/repo/pnpm-lock.yaml"}}' 2
t "Gemfile.lock の編集をブロック"    "$P" '{"tool_input":{"file_path":"/repo/Gemfile.lock"}}' 2
t "go.sum の編集をブロック"          "$P" '{"tool_input":{"file_path":"/repo/go.sum"}}' 2
# Accepted ADR の期待値は「その ADR が origin/main に在るか」で決まる（guard の契約そのもの。
# マージ済み＝編集禁止 / 未マージ＝導入前なので訂正可）。ブロック固定にすると、ADR がまだ main に
# 無いリポジトリで偽赤になる。マージ済み側は下の隔離 git リポジトリが決定論的に網羅している。
# guard は3状態を持つ。許可になるのは真ん中だけで、origin/main を参照できない環境
# （CI の浅い checkout など）は「未マージ」ではなく fail-closed でブロックに倒れる。
A="docs/adr/0001-steering-placement-policy.md"
if ! git rev-parse --verify -q origin/main >/dev/null 2>&1; then
  AW=2; AS="origin/main 参照不能→fail-closed"
elif git cat-file -e "origin/main:$A" 2>/dev/null; then
  AW=2; AS="main マージ済み→ブロック"
else
  AW=0; AS="main 未マージ→訂正可"
fi
t "Accepted ADR の編集（$AS）"      "$P" "{\"tool_input\":{\"file_path\":\"$PWD/$A\"}}" "$AW"
t "supersede の Status 行更新は許可" "$P" "{\"tool_input\":{\"file_path\":\"$PWD/$A\",\"old_string\":\"- Status: Accepted\",\"new_string\":\"- Status: Superseded by 0099\"}}" 0
t "supersede の new_string 本文注入(複数行)は例外に乗らない（$AS）" "$P" "{\"tool_input\":{\"file_path\":\"$PWD/$A\",\"old_string\":\"- Status: Accepted\",\"new_string\":\"- Status: Superseded by 0099\\n\\nEVIL 本文改ざん\"}}" "$AW"
t "supersede 例外の全文改変は例外に乗らない（$AS）" "$P" "{\"tool_input\":{\"file_path\":\"$PWD/$A\",\"old_string\":\"# 0001: x\\n- Status: Accepted\\n## Context\",\"new_string\":\"改変本文 Superseded by 0099\"}}" "$AW"
t "Status 行以外の Accepted ADR 編集（$AS）" "$P" "{\"tool_input\":{\"file_path\":\"$PWD/$A\",\"old_string\":\"## Context\",\"new_string\":\"## Changed\"}}" "$AW"
t "ADR template の編集を許可"        "$P" "{\"tool_input\":{\"file_path\":\"$PWD/docs/adr/template.md\"}}" 0
t "通常ファイルの編集を許可"         "$P" '{"tool_input":{"file_path":"/repo/README.md"}}' 0
t "空入力を許可（フェイルオープン）" "$P" '{}' 0

# --- guard-protected: ADR governance を隔離 git リポジトリで決定論的に検証 ---
# 「main にマージ済みの ADR は編集ブロック / main 未マージの ADR は訂正可」
if command -v git >/dev/null 2>&1; then
  gw=$(mktemp -d)
  git init -q --bare "$gw/o.git"
  git clone -q "$gw/o.git" "$gw/c" 2>/dev/null
  (
    cd "$gw/c" || exit 1
    git config user.email t@example.com; git config user.name tester
    mkdir -p docs/adr
    printf '# 0001\n- Status: Accepted\n\n## Context\nx\n' > docs/adr/0001-on.md
    git add -A; git commit -qm init; git push -q origin HEAD:main; git fetch -q origin
  ) >/dev/null 2>&1
  # main 未マージの Accepted ADR（push しない）
  printf '# 0002\n- Status: Accepted\n\n## Context\ny\n' > "$gw/c/docs/adr/0002-off.md"
  # @description 隔離リポジトリ内の ADR を編集する擬似ツールコールを guard-protected に流す。
  # @internal
  # @arg $1 string ケースの説明
  # @arg $2 path 隔離リポジトリからの ADR 相対パス
  # @arg $3 int 期待する終了コード
  # @set fail int 不一致なら 1
  tg() { # $1=説明 $2=ADR相対パス $3=期待exit
    printf '{"tool_input":{"file_path":"%s","old_string":"## Context","new_string":"## X"}}' "$gw/c/$2" \
      | CLAUDE_PROJECT_DIR="$gw/c" bash "$P" >/dev/null 2>&1
    if [ $? -eq "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1" >&2; fail=1; fi
  }
  tg "main マージ済み ADR の編集をブロック" docs/adr/0001-on.md 2
  tg "main 未マージ ADR の編集を許可"       docs/adr/0002-off.md 0
  # CLAUDE_PROJECT_DIR に末尾スラッシュがあってもブロックが効く（fail-open 回帰）
  printf '{"tool_input":{"file_path":"%s","old_string":"## Context","new_string":"## X"}}' "$gw/c/docs/adr/0001-on.md" \
    | CLAUDE_PROJECT_DIR="$gw/c/" bash "$P" >/dev/null 2>&1
  if [ $? -eq 2 ]; then echo "PASS: 末尾スラッシュでもマージ済みADRをブロック"; else echo "FAIL: 末尾スラッシュでもマージ済みADRをブロック" >&2; fail=1; fi
  # 回帰(GP-symlink): proj と file_path が symlink vs realpath で食い違っても fail-open しない。
  #   CLAUDE_PROJECT_DIR=realpath, file_path=symlink 経路（マージ済み ADR）→ ブロックされること。
  ln -s "$gw/c" "$gw/link" 2>/dev/null
  if [ -L "$gw/link" ]; then
    printf '{"tool_input":{"file_path":"%s","old_string":"## Context","new_string":"## X"}}' "$gw/link/docs/adr/0001-on.md" \
      | CLAUDE_PROJECT_DIR="$gw/c" bash "$P" >/dev/null 2>&1
    if [ $? -eq 2 ]; then echo "PASS: symlink経路でもマージ済みADRをブロック(fail-open回帰)"; else echo "FAIL: symlink経路でマージ済みADRが編集可能(fail-open)" >&2; fail=1; fi
    # 逆向き: proj=symlink, file_path=realpath でも未マージ ADR は正しく許可（過剰ブロックしない）
    printf '{"tool_input":{"file_path":"%s","old_string":"## Context","new_string":"## X"}}' "$gw/c/docs/adr/0002-off.md" \
      | CLAUDE_PROJECT_DIR="$gw/link" bash "$P" >/dev/null 2>&1
    if [ $? -eq 0 ]; then echo "PASS: symlink proj でも未マージADRは許可(過剰ブロックしない)"; else echo "FAIL: symlink proj で未マージADRを誤ブロック" >&2; fail=1; fi
  fi
  rm -rf "$gw"
fi

# --- guard-git: 保護ブランチ上でのカレントブランチ push を隔離 git リポジトリで検証（GG-2 回帰） ---
# push 先未指定は origin/upstream 以外のリモート名でも検査対象になること（名前ホワイトリスト依存の排除）
if command -v git >/dev/null 2>&1; then
  gg=$(mktemp -d)
  ( cd "$gg" && git init -q && git checkout -q -b main && git config user.email t@e.x && git config user.name t && git commit -q --allow-empty -m x ) >/dev/null 2>&1
  cp "$G" "$gg/guard.sh"
  # @description 隔離 git リポジトリ（カレントブランチが既知）で guard-git を実行する。
  #   カレントブランチ依存の判定を実リポジトリの状態に左右されず検証するため。
  # @internal
  # @arg $1 string ケースの説明
  # @arg $2 string 検査する git コマンド文字列
  # @arg $3 int 期待する終了コード
  # @set fail int 不一致なら 1
  gt() { # $1=説明 $2=command $3=期待exit
    printf '{"tool_input":{"command":"%s"}}' "$2" | CLAUDE_PROJECT_DIR="$gg" bash "$gg/guard.sh" >/dev/null 2>&1
    if [ $? -eq "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1" >&2; fail=1; fi
  }
  gt "main上: 非origin リモートへの push をブロック" "git push gitlab" 2
  gt "main上: push先未指定をブロック"                "git push" 2
  gt "main上: 別ブランチ明示 push は許可"             "git push origin feature" 0
  gt "main上: 裸 HEAD push をブロック（カレント=main）" "git push origin HEAD" 2
  ( cd "$gg" && git checkout -q -b feat ) >/dev/null 2>&1
  gt "feat上: カレント push は許可（非保護）"          "git push gitlab" 0
  gt "feat上: 裸 HEAD push は許可（非保護）"           "git push origin HEAD" 0
  # 誤爆回帰(GG4): `--all-of-them` は --all/--mirror 正規表現に一致しない。非保護ブランチ上で
  # 検証してカレントブランチ検査(3)の影響を排除する（CI が main 上で走ると (3) が正しく
  # ブロックし、実リポジトリ依存の非決定的テストになるのを避ける）。
  gt "feat上: --all-of-them は誤爆しない（--all/mirror regex）" "git push origin --all-of-them" 0
  rm -rf "$gg"
fi

# --- session-start.sh: detached HEAD でブランチ表示が空にならない（回帰） ---
if command -v git >/dev/null 2>&1; then
  ss=$(mktemp -d)
  ( cd "$ss" && git init -q && git config user.email t@e.x && git config user.name t \
     && git commit -q --allow-empty -m a && git commit -q --allow-empty -m b && git checkout -q HEAD~1 ) >/dev/null 2>&1
  mkdir -p "$ss/.claude/hooks"; cp .claude/hooks/session-start.sh "$ss/.claude/hooks/"
  ln=$( cd "$ss" && CLAUDE_PROJECT_DIR="$ss" bash .claude/hooks/session-start.sh 2>/dev/null | grep 'ブランチ' )
  case "$ln" in *detached*) echo "PASS: detached HEAD でブランチが空にならない";; *) echo "FAIL: detached HEAD でブランチ表示が空" >&2; fail=1;; esac
  rm -rf "$ss"
fi

# ============================================================================
# quality-gate.sh（Stop フック）と session-start.sh の契約テスト（Round 9・#35）
#
# 方針:
#  - 実リポジトリの状態（カレントブランチ・未コミット変更の有無）に依存させない。
#    すべて mktemp -d の隔離 git リポジトリで検証し、最後に rm -rf する。
#  - 本物の scripts/check.sh は絶対に実行しない（重い）。隔離リポジトリに偽の check.sh
#    （即 exit する軽量スタブ）を置き、フックの分岐だけを決定論的に見る。
#  - スタブは「実行回数カウンタ」と「終了コードファイル」で制御し、キャッシュ挙動
#    （＝ゲートを実際に走らせたか）まで観測する。
# ============================================================================
ROOT=$PWD
QG="$ROOT/.claude/hooks/quality-gate.sh"
SS="$ROOT/.claude/hooks/session-start.sh"

# @description 実際の値が期待値と一致することを表明する。
# @internal
# @arg $1 string ケースの説明
# @arg $2 string 実際の値
# @arg $3 string 期待する値
# @set fail int 不一致なら 1
a_eq()     { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (want=[$3] got=[$2])" >&2; fail=1; fi; }
# @description 実際の値が指定の部分文字列を含むことを表明する。
# @internal
# @arg $1 string ケースの説明
# @arg $2 string 実際の値
# @arg $3 string 含むべき部分文字列
# @set fail int 含まなければ 1
a_has()    { case "$2" in *"$3"*) echo "PASS: $1";; *) echo "FAIL: $1 (含むべき文字列なし: $3)" >&2; fail=1;; esac; }
# @description 実際の値が指定の部分文字列を含まないことを表明する（機密漏洩の検査等）。
# @internal
# @arg $1 string ケースの説明
# @arg $2 string 実際の値
# @arg $3 string 含んではいけない部分文字列
# @set fail int 含んでいたら 1
a_hasnot() { case "$2" in *"$3"*) echo "FAIL: $1 (含んではいけない文字列: $3)" >&2; fail=1;; *) echo "PASS: $1";; esac; }

if ! command -v git >/dev/null 2>&1; then
  echo "SKIP: quality-gate.sh / session-start.sh の契約テスト（git が無い）" >&2
  fail=1
else
  W=$(mktemp -d)
  # @description main ブランチ・初期コミット済みの隔離 git リポジトリを作る。
  # @internal
  # @arg $1 path 作成先ディレクトリ
  mkrepo() { # $1=dir : main ブランチの空リポジトリを作る
    mkdir -p "$1"
    ( cd "$1" && git init -q && git checkout -q -b main && git config user.email t@e.x \
        && git config user.name t && git commit -q --allow-empty -m init ) >/dev/null 2>&1
  }
  # @description 偽の scripts/check.sh（軽量スタブ）を置く。本物の check.sh は重いので絶対に実行しない。
  #   実行のたびにカウンタファイルへ1行追記するので、「ゲートを実際に走らせたか」（キャッシュ挙動）まで観測できる。
  # @internal
  # @arg $1 path スタブを置くリポジトリのルート
  # @arg $2 path 実行回数カウンタファイル
  # @arg $3 int スタブが返す終了コード
  mkstub() { # $1=dir $2=カウンタファイル $3=終了コード : 偽 check.sh を置く
    mkdir -p "$1/scripts"
    printf '#!/usr/bin/env bash\necho run >> "%s"\necho CHECKSH_LOG_MARKER\nexit %s\n' "$2" "$3" \
      > "$1/scripts/check.sh"
    chmod +x "$1/scripts/check.sh"
  }
  # @description スタブ check.sh の実行回数を返す（カウンタファイルの行数）。
  # @internal
  # @arg $1 path 実行回数カウンタファイル
  # @stdout 実行回数（ファイルが無ければ 0）
  nruns() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

  # --- quality-gate.sh: 主リポジトリ（終了コードをファイルで切り替えられるスタブ） ---
  QD="$W/repo"; CNT="$W/runs"; RCF="$W/rc"; CACHE="$W/repo/.git/deb-quality-gate.pass"
  mkrepo "$QD"; : > "$CNT"; echo 0 > "$RCF"
  mkdir -p "$QD/scripts"
  printf '#!/usr/bin/env bash\necho run >> "%s"\necho CHECKSH_LOG_MARKER\nexit "$(cat "%s")"\n' \
    "$CNT" "$RCF" > "$QD/scripts/check.sh"
  chmod +x "$QD/scripts/check.sh"
  ( cd "$QD" && git add -A && git commit -qm stub ) >/dev/null 2>&1
  # @description 次回以降スタブ check.sh が返す終了コードを切り替える。
  # @internal
  # @arg $1 int スタブに返させる終了コード（0=ゲート成功 / 非0=失敗）
  gate_rc() { echo "$1" > "$RCF"; }
  # @description quality-gate.sh をフック JSON 付きで実行し、結果を変数に取り込む。
  # @internal
  # @arg $1 string stdin に流すフック JSON
  # @set qexit int quality-gate.sh の終了コード
  # @set qout string 標準出力の内容
  # @set qerr string 標準エラーの内容
  qg() { # $1=フック JSON : qexit / qout / qerr を設定
    printf '%s' "$1" | CLAUDE_PROJECT_DIR="$QD" bash "$QG" >"$W/o" 2>"$W/e"
    qexit=$?; qout=$(cat "$W/o"); qerr=$(cat "$W/e")
  }

  # 1) 未コミット変更が無いとき: 素通り。ゲートは走らせない（体感速度の契約）
  gate_rc 1
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: 変更なしなら exit 0"                          "$qexit" 0
  a_eq "QG: 変更なしならゲートを実行しない"               "$(nruns "$CNT")" "$n"
  a_eq "QG: 変更なしなら stdout は空"                     "$qout" ""
  a_eq "QG: 変更なしなら stderr は空"                     "$qerr" ""
  # gitignore 済みの変更はゲート対象外（git status --porcelain の契約に一致）
  printf 'ignored.txt\n' > "$QD/.gitignore"
  ( cd "$QD" && git add -A && git commit -qm ignore ) >/dev/null 2>&1
  echo x > "$QD/ignored.txt"
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: gitignore 対象の変更だけなら exit 0"          "$qexit" 0
  a_eq "QG: gitignore 対象だけならゲートを実行しない"     "$(nruns "$CNT")" "$n"

  # 2) 変更あり＋ゲート成功: 通す／合格キャッシュを書く
  gate_rc 0; echo v1 > "$QD/a.txt"
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: 変更あり＋ゲート成功なら exit 0"              "$qexit" 0
  a_eq "QG: 変更ありならゲートを実行する"                 "$(nruns "$CNT")" "$((n + 1))"
  a_eq "QG: 成功時 stdout は空（フック出力を汚さない）"   "$qout" ""
  a_eq "QG: 成功時 stderr は空"                           "$qerr" ""
  if [ -f "$CACHE" ]; then r=yes; else r=no; fi
  a_eq "QG: 成功時に合格キャッシュを書く"                 "$r" yes
  a_eq "QG: キャッシュは 40 桁の SHA-1"                   "$(cat "$CACHE" | tr -d '\n' | wc -c | tr -d ' ')" 40
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: 同一状態の再実行も exit 0"                    "$qexit" 0
  a_eq "QG: 同一状態ではゲートを再実行しない（キャッシュ命中）" "$(nruns "$CNT")" "$n"

  # 3) キャッシュ無効化: porcelain に現れない変化も拾うこと
  echo v2 > "$QD/a.txt"                       # 未追跡ファイルの「内容だけ」変更（?? a.txt のまま）
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: 未追跡ファイルの内容変更でキャッシュ無効化"   "$(nruns "$CNT")" "$((n + 1))"
  ( cd "$QD" && git add a.txt ) >/dev/null 2>&1
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: staged 化でキャッシュ無効化"                  "$(nruns "$CNT")" "$((n + 1))"
  echo v3 >> "$QD/a.txt"
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: 作業ツリー差分でキャッシュ無効化"             "$(nruns "$CNT")" "$((n + 1))"
  ( cd "$QD" && git add -A && git commit -qm a ) >/dev/null 2>&1
  rm -f "$QD/a.txt"
  n=$(nruns "$CNT"); qg '{}'
  a_eq "QG: 追跡ファイル削除もゲート対象"                 "$(nruns "$CNT")" "$((n + 1))"
  ( cd "$QD" && git checkout -q -- a.txt ) >/dev/null 2>&1

  # 4) 変更あり＋ゲート失敗: ターン終了をブロックし、理由と再現手段を stderr に出す
  gate_rc 1; echo f1 > "$QD/dirty.txt"
  qg '{}'
  a_eq  "QG: ゲート失敗ならターン終了をブロック（exit 2）" "$qexit" 2
  a_has "QG: 失敗時 stderr に失敗の理由"                  "$qerr" "品質ゲート失敗"
  a_has "QG: 失敗時 stderr に再現手段 scripts/check.sh"   "$qerr" "scripts/check.sh"
  a_has "QG: 失敗時 stderr に失敗ログ末尾を添付"          "$qerr" "CHECKSH_LOG_MARKER"
  a_eq  "QG: 失敗時 stdout は空（stderr のみで伝える）"   "$qout" ""
  n=$(nruns "$CNT"); qg '{}'
  a_eq  "QG: 失敗はキャッシュしない（毎ターン再実行）"    "$(nruns "$CNT")" "$((n + 1))"
  a_eq  "QG: 失敗が続く限りブロックし続ける"              "$qexit" 2
  a_hasnot "QG: 失敗時にキャッシュを更新しない"           "$(cat "$CACHE" 2>/dev/null)" "$(cd "$QD" && git status --porcelain | sha1sum | cut -d' ' -f1)"
  gate_rc 3; echo f2 > "$QD/dirty.txt"; qg '{}'
  a_eq  "QG: 終了コード 3 でもブロック（非ゼロは一律 exit 2）" "$qexit" 2
  gate_rc 127; echo f3 > "$QD/dirty.txt"; qg '{}'
  a_eq  "QG: 終了コード 127 でもブロック"                 "$qexit" 2

  # 5) 無限ループ防止: stop_hook_active が真なら再帰せず警告のみ
  gate_rc 1; echo s1 > "$QD/dirty.txt"
  n=$(nruns "$CNT"); qg '{"stop_hook_active":true}'
  a_eq  "QG: stop_hook_active=true なら exit 0（再帰しない）" "$qexit" 0
  a_eq  "QG: stop_hook_active=true ではゲートを実行しない" "$(nruns "$CNT")" "$n"
  a_has "QG: stop_hook_active=true で stderr に警告"      "$qerr" "連続で失敗"
  a_eq  "QG: stop_hook_active=true でも stdout は空"      "$qout" ""
  qg '{"session_id":"x", "stop_hook_active" : true , "cwd":"/w"}'
  a_eq  "QG: 空白入りの stop_hook_active も真と解釈"      "$qexit" 0
  qg '{
  "session_id": "abc",
  "stop_hook_active": true
}'
  a_eq  "QG: 整形済み（複数行）JSON でも真と解釈"        "$qexit" 0
  printf '{\r\n  "stop_hook_active": true\r\n}\r\n' | CLAUDE_PROJECT_DIR="$QD" bash "$QG" >/dev/null 2>&1
  a_eq  "QG: CRLF 改行の JSON でも真と解釈"              "$?" 0
  qg '{"stop_hook_active":false}'
  a_eq  "QG: stop_hook_active=false ならブロック"        "$qexit" 2
  qg '{"stop_hook_active":"true"}'
  a_eq  "QG: 文字列 \"true\" は真扱いしない（ブロック）" "$qexit" 2
  qg '{"session_id":"x","cwd":"/w"}'
  a_eq  "QG: stop_hook_active 不在ならブロック"          "$qexit" 2
  qg '{"stop_hook_active":false,"cwd":"/x/\"stop_hook_active\": true/y"}'
  a_eq  "QG: 文字列値に埋めた偽装キーで降格されない"     "$qexit" 2

  # 6) 壊れた入力・想定外入力は fail-closed（ゲートを走らせてブロックする）
  gate_rc 1; echo b1 > "$QD/dirty.txt"
  qg ''
  a_eq "QG: 空入力でもゲートを実行しブロック"            "$qexit" 2
  qg 'not json at all {{{'
  a_eq "QG: 非 JSON 入力でもブロック"                    "$qexit" 2
  qg '[]'
  a_eq "QG: 配列 JSON でもブロック"                      "$qexit" 2
  qg 'null'
  a_eq "QG: null 入力でもブロック"                       "$qexit" 2
  qg '{"unknown_key":{"nested":[1,2,3]}}'
  a_eq "QG: 想定外キーのみでもブロック"                  "$qexit" 2
  big=$(head -c 100000 /dev/zero | tr '\0' 'a')
  qg "{\"session_id\":\"$big\",\"stop_hook_active\":false}"
  a_eq "QG: 100KB の入力でも stdin を読み切ってブロック" "$qexit" 2
  printf '{"x":"\000\001\002","stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$QD" bash "$QG" >/dev/null 2>&1
  a_eq "QG: NUL バイト混じりの入力でもブロック"          "$?" 2
  CLAUDE_PROJECT_DIR="$QD" bash "$QG" >/dev/null 2>&1 </dev/null
  a_eq "QG: stdin が空(/dev/null)でもブロック"           "$?" 2

  # 7) check.sh の存在・実行可否
  QN="$W/nocheck"; mkrepo "$QN"; echo x > "$QN/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QN" bash "$QG" >/dev/null 2>&1
  a_eq "QG: check.sh が無ければ素通り（exit 0）"         "$?" 0
  # 実行ビットが落ちていても bash 経由で実行できる以上、ゲートを飛ばしてはならない
  # （Windows/マウント FS/zip 展開で mode が落ちるとゲートが黙って無効化されるのを防ぐ）
  QX="$W/noexec"; CX="$W/noexec.runs"; mkrepo "$QX"; mkstub "$QX" "$CX" 1
  chmod -x "$QX/scripts/check.sh"; echo x > "$QX/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QX" bash "$QG" >/dev/null 2>&1
  a_eq "QG: check.sh の実行ビットが無くてもゲートを走らせる（ブロック）" "$?" 2
  a_eq "QG: 実行ビットが無くても check.sh は実行される"  "$(nruns "$CX")" 1
  QE="$W/empty"; mkrepo "$QE"; mkdir -p "$QE/scripts"; : > "$QE/scripts/check.sh"
  chmod +x "$QE/scripts/check.sh"; echo x > "$QE/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QE" bash "$QG" >/dev/null 2>&1
  a_eq "QG: 空の check.sh（成功扱い）なら通す"           "$?" 0

  # 8) git リポジトリでない / detached HEAD / unborn HEAD
  QG2="$W/nogit"; CG2="$W/nogit.runs"; mkdir -p "$QG2"; mkstub "$QG2" "$CG2" 1
  echo x > "$QG2/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QG2" bash "$QG" >/dev/null 2>&1
  a_eq "QG: git リポジトリ外なら素通り（exit 0）"        "$?" 0
  a_eq "QG: git リポジトリ外では check.sh を実行しない"  "$(nruns "$CG2")" 0
  QDT="$W/detached"; CDT="$W/detached.runs"; mkrepo "$QDT"; mkstub "$QDT" "$CDT" 1
  ( cd "$QDT" && git add -A && git commit -qm stub && git commit -q --allow-empty -m b \
      && git checkout -q HEAD~1 ) >/dev/null 2>&1
  echo x > "$QDT/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QDT" bash "$QG" >/dev/null 2>&1
  a_eq "QG: detached HEAD でも変更を検出してブロック"    "$?" 2
  QU="$W/unborn"; CU="$W/unborn.runs"; mkdir -p "$QU"
  ( cd "$QU" && git init -q && git checkout -q -b main ) >/dev/null 2>&1
  mkstub "$QU" "$CU" 1; echo x > "$QU/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QU" bash "$QG" >/dev/null 2>&1
  a_eq "QG: unborn HEAD（コミット0件）でもブロック"      "$?" 2

  # 9) CLAUDE_PROJECT_DIR の扱い
  gate_rc 1; echo p1 > "$QD/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$W/does-not-exist" bash "$QG" >"$W/o" 2>"$W/e"
  a_eq "QG: 存在しない CLAUDE_PROJECT_DIR なら素通り"    "$?" 0
  a_eq "QG: cd 失敗時は stdout を汚さない"               "$(cat "$W/o")" ""
  a_eq "QG: cd 失敗時は stderr を汚さない"               "$(cat "$W/e")" ""
  printf '{}' | CLAUDE_PROJECT_DIR="$QD/" bash "$QG" >/dev/null 2>&1
  a_eq "QG: 末尾スラッシュ付きでも正しくブロック"        "$?" 2
  ( cd "$QD" && printf '{}' | env -u CLAUDE_PROJECT_DIR bash "$QG" ) >/dev/null 2>&1
  a_eq "QG: CLAUDE_PROJECT_DIR 未設定＋cwd=プロジェクトでブロック" "$?" 2
  mkdir -p "$QD/sub"
  ( cd "$QD/sub" && printf '{}' | CLAUDE_PROJECT_DIR="$QD" bash "$QG" ) >/dev/null 2>&1
  a_eq "QG: サブディレクトリから呼ばれてもブロック"      "$?" 2

  # 10) キャッシュファイルが書けない環境でも判定は変わらない（.git/ 直下が使えない等）
  QC="$W/nocache"; CC="$W/nocache.runs"; mkrepo "$QC"; mkstub "$QC" "$CC" 0
  mkdir -p "$QC/.git/deb-quality-gate.pass"   # 書き込み不能（ディレクトリを置く）
  echo x > "$QC/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QC" bash "$QG" >/dev/null 2>&1
  a_eq "QG: キャッシュ書込不能でも成功時は exit 0"       "$?" 0
  mkstub "$QC" "$CC" 1; echo y > "$QC/dirty.txt"
  printf '{}' | CLAUDE_PROJECT_DIR="$QC" bash "$QG" >/dev/null 2>&1
  a_eq "QG: キャッシュ書込不能でも失敗時は exit 2"       "$?" 2

  # 11) ツール欠落（sha1sum 不在）でゲートが無効化されないこと
  #     state_hash が空のままキャッシュされると「常にキャッシュ命中」＝ゲート恒久停止になる
  QS="$W/nosha"; CS="$W/nosha.runs"; SHIM="$W/shim"; mkrepo "$QS"; mkstub "$QS" "$CS" 0
  mkdir -p "$SHIM"; printf '#!/bin/sh\nexit 127\n' > "$SHIM/sha1sum"; chmod +x "$SHIM/sha1sum"
  echo x > "$QS/dirty.txt"
  printf '{}' | env PATH="$SHIM:$PATH" CLAUDE_PROJECT_DIR="$QS" bash "$QG" >/dev/null 2>&1
  a_eq "QG: sha1sum 不在でも成功時は exit 0"             "$?" 0
  if [ -s "$QS/.git/deb-quality-gate.pass" ]; then r=nonempty; else r=empty-or-absent; fi
  a_eq "QG: sha1sum 不在時に空ハッシュをキャッシュしない" "$r" empty-or-absent
  mkstub "$QS" "$CS" 1; echo y > "$QS/dirty.txt"
  printf '{}' | env PATH="$SHIM:$PATH" CLAUDE_PROJECT_DIR="$QS" bash "$QG" >/dev/null 2>&1
  a_eq "QG: sha1sum 不在でも状態変化後の失敗をブロック"  "$?" 2
  n=$(nruns "$CS")
  printf '{}' | env PATH="$SHIM:$PATH" CLAUDE_PROJECT_DIR="$QS" bash "$QG" >/dev/null 2>&1
  a_eq "QG: sha1sum 不在なら毎回ゲートを実行する"        "$(nruns "$CS")" "$((n + 1))"

  # --- session-start.sh ---
  # @description session-start.sh を指定プロジェクトディレクトリで実行し、結果を変数に取り込む。
  # @internal
  # @arg $1 path CLAUDE_PROJECT_DIR に渡す値
  # @set sexit int session-start.sh の終了コード
  # @set sout string 標準出力の内容
  # @set serr string 標準エラーの内容
  ssrun() { # $1=CLAUDE_PROJECT_DIR : sexit / sout / serr を設定
    CLAUDE_PROJECT_DIR="$1" bash "$SS" >"$W/o" 2>"$W/e" </dev/null
    sexit=$?; sout=$(cat "$W/o"); serr=$(cat "$W/e")
  }
  SD="$W/ss-main"; mkrepo "$SD"; mkstub "$SD" "$W/ss.runs" 0
  mkdir -p "$SD/docs/adr"
  for i in 1 2 3 4 5; do printf 'x\n' > "$SD/docs/adr/000$i-a.md"; done
  ( cd "$SD" && git add -A && git commit -qm files ) >/dev/null 2>&1
  ssrun "$SD"
  a_eq  "SS: 正常時 exit 0"                              "$sexit" 0
  a_eq  "SS: 1行目は見出し"                              "$(printf '%s\n' "$sout" | head -1)" "## セッション開始時の状態"
  a_has "SS: ブランチ名を表示"                           "$sout" "- ブランチ: main"
  a_has "SS: クリーンな作業ツリーを表示"                 "$sout" "- 作業ツリーはクリーン"
  a_hasnot "SS: クリーン時に未コミット変更を表示しない"  "$sout" "未コミット変更あり"
  a_has "SS: 直近 ADR の見出しを表示"                    "$sout" "- 直近のADR:"
  a_eq  "SS: 直近 ADR は3件まで"                         "$(printf '%s\n' "$sout" | grep -c 'docs/adr/')" 3
  a_has "SS: ADR は末尾3件（0005）"                      "$sout" "docs/adr/0005-a.md"
  a_hasnot "SS: ADR は末尾3件（0002 は出さない）"        "$sout" "docs/adr/0002-a.md"
  a_has "SS: check.sh があれば品質ゲートを案内"          "$sout" "品質ゲート: scripts/check.sh"
  a_eq  "SS: 正常時 stderr は空"                         "$serr" ""

  # 機密が漏れないこと（ファイル名は出るが中身は出さない）
  printf 'API_TOKEN=deb_TEST_CANARY_MUST_NOT_LEAK\n' > "$SD/.env"
  ssrun "$SD"
  a_eq     "SS: .env があっても exit 0"                  "$sexit" 0
  a_has    "SS: 未コミット変更を表示"                    "$sout" "- 未コミット変更あり:"
  a_has    "SS: 変更ファイル名は表示する"                "$sout" ".env"
  a_hasnot "SS: .env の中身を出力しない"                 "$sout" "CANARY_MUST_NOT_LEAK"
  a_hasnot "SS: .env の中身を stderr にも出さない"       "$serr" "CANARY_MUST_NOT_LEAK"
  ( cd "$SD" && git add -A && git commit -qm env ) >/dev/null 2>&1
  printf 'API_TOKEN=deb_TEST_CANARY_MUST_NOT_LEAK2\n' > "$SD/.env"
  ssrun "$SD"
  a_hasnot "SS: 追跡済み .env の差分内容も出力しない"    "$sout" "CANARY_MUST_NOT_LEAK2"
  a_has    "SS: 追跡済み .env の変更はファイル名で示す"  "$sout" "M .env"
  ( cd "$SD" && git checkout -q -- .env ) >/dev/null 2>&1

  # 未コミット変更の表示は10件まで・4スペース字下げ（ADR 行と混ざらない環境で数える）
  SDD="$W/ss-dirty"; mkrepo "$SDD"
  i=1; while [ "$i" -le 15 ]; do printf 'x\n' > "$SDD/f$(printf '%02d' "$i").txt"; i=$((i + 1)); done
  ssrun "$SDD"
  a_eq  "SS: 汚れた作業ツリーでも exit 0"                "$sexit" 0
  a_eq  "SS: 未コミット変更の表示は10件まで"             "$(printf '%s\n' "$sout" | grep -c '^    ')" 10
  a_has "SS: 変更行は4スペース字下げ"                    "$sout" "    ?? f01.txt"
  a_hasnot "SS: 11件目以降は表示しない"                  "$sout" "f15.txt"
  a_hasnot "SS: docs/adr が無ければ ADR 節を出さない"    "$sout" "直近のADR"
  a_has "SS: check.sh が無ければ警告する"                "$sout" "警告: scripts/check.sh が無い/実行不可"
  chmod -x "$SDD/f01.txt" 2>/dev/null
  mkdir -p "$SDD/scripts"; printf '#!/usr/bin/env bash\nexit 0\n' > "$SDD/scripts/check.sh"
  ssrun "$SDD"
  a_has "SS: check.sh が実行不可なら警告する"            "$sout" "警告: scripts/check.sh が無い/実行不可"

  # docs/adr のバリエーション
  SDE="$W/ss-adr-empty"; mkrepo "$SDE"; mkdir -p "$SDE/docs/adr"
  ssrun "$SDE"
  a_eq     "SS: 空の docs/adr でも exit 0"               "$sexit" 0
  a_hasnot "SS: 空の docs/adr では ADR 節を出さない"     "$sout" "直近のADR"
  printf 'x\n' > "$SDE/docs/adr/template.md"; printf 'x\n' > "$SDE/docs/adr/README.md"
  ssrun "$SDE"
  a_hasnot "SS: 番号なしファイルのみなら ADR 節を出さない" "$sout" "直近のADR"
  a_eq     "SS: 番号なしファイルのみでも exit 0"         "$sexit" 0
  SDM="$W/ss-adr-many"; mkrepo "$SDM"; mkdir -p "$SDM/docs/adr"
  i=1; while [ "$i" -le 30 ]; do printf 'x\n' > "$SDM/docs/adr/$(printf '%04d' "$i")-a.md"; i=$((i + 1)); done
  ssrun "$SDM"
  a_eq  "SS: ADR が30件でも表示は3件"                    "$(printf '%s\n' "$sout" | grep -c 'docs/adr/')" 3
  a_has "SS: ADR 30件のとき最新(0030)を表示"             "$sout" "docs/adr/0030-a.md"
  a_hasnot "SS: ADR 30件のとき古いもの(0027)は出さない"  "$sout" "docs/adr/0027-a.md"
  a_eq  "SS: ADR 大量でも exit 0"                        "$sexit" 0

  # detached HEAD / unborn HEAD / git が無い環境
  SDT="$W/ss-detached"; mkrepo "$SDT"
  ( cd "$SDT" && git commit -q --allow-empty -m b && git checkout -q HEAD~1 ) >/dev/null 2>&1
  ssrun "$SDT"
  a_eq     "SS: detached HEAD でも exit 0"               "$sexit" 0
  a_has    "SS: detached HEAD で detached 表記"          "$sout" "- ブランチ: (detached: "
  a_hasnot "SS: detached HEAD で SHA 解決に失敗しない"   "$sout" "(detached: ?)"
  a_eq     "SS: detached の短SHA が空でない"             "$(printf '%s\n' "$sout" | grep -c '^- ブランチ: (detached: [0-9a-f][0-9a-f]*)$')" 1
  SU="$W/ss-unborn"; mkdir -p "$SU"
  ( cd "$SU" && git init -q && git checkout -q -b main ) >/dev/null 2>&1
  ssrun "$SU"
  a_eq     "SS: unborn HEAD でも exit 0"                 "$sexit" 0
  a_has    "SS: unborn HEAD でもブランチ名を表示"        "$sout" "- ブランチ: main"
  a_hasnot "SS: unborn HEAD を detached と誤表示しない"  "$sout" "detached"
  a_has    "SS: unborn HEAD はクリーン表示"              "$sout" "- 作業ツリーはクリーン"
  SNG="$W/ss-nogit"; mkdir -p "$SNG"
  ssrun "$SNG"
  a_eq     "SS: git リポジトリ外でも exit 0"             "$sexit" 0
  a_has    "SS: git リポジトリ外でも見出しは出す"        "$sout" "## セッション開始時の状態"
  a_hasnot "SS: git リポジトリ外ではブランチ行を出さない" "$sout" "- ブランチ:"
  a_eq     "SS: git リポジトリ外でも stderr は空"        "$serr" ""
  GSHIM="$W/gitshim"; mkdir -p "$GSHIM"
  printf '#!/bin/sh\nexit 127\n' > "$GSHIM/git"; chmod +x "$GSHIM/git"
  env PATH="$GSHIM:$PATH" CLAUDE_PROJECT_DIR="$SD" bash "$SS" >"$W/o" 2>"$W/e" </dev/null
  a_eq     "SS: git が使えなくても exit 0"               "$?" 0
  a_has    "SS: git が使えなくても見出しは出す"          "$(cat "$W/o")" "## セッション開始時の状態"
  a_hasnot "SS: git が使えないときブランチ行を出さない"  "$(cat "$W/o")" "- ブランチ:"
  a_has    "SS: git が使えなくても品質ゲート案内は出す"  "$(cat "$W/o")" "品質ゲート: scripts/check.sh"
  env -i PATH="" CLAUDE_PROJECT_DIR="$SD" "$(command -v bash)" "$SS" >"$W/o" 2>"$W/e"
  a_eq     "SS: PATH が空でも exit 0（セッションを壊さない）" "$?" 0
  a_has    "SS: PATH が空でも見出しは出す"               "$(cat "$W/o")" "## セッション開始時の状態"

  # CLAUDE_PROJECT_DIR の扱い
  ssrun "$W/does-not-exist"
  a_eq "SS: 存在しない CLAUDE_PROJECT_DIR でも exit 0"   "$sexit" 0
  a_eq "SS: cd 失敗時は stdout を汚さない"               "$sout" ""
  a_eq "SS: cd 失敗時は stderr を汚さない"               "$serr" ""
  ssrun "$SD/"
  a_has "SS: 末尾スラッシュ付きでも動作する"             "$sout" "- ブランチ: main"
  ( cd "$SD" && env -u CLAUDE_PROJECT_DIR bash "$SS" ) >"$W/o" 2>&1
  a_has "SS: CLAUDE_PROJECT_DIR 未設定＋cwd でも動作する" "$(cat "$W/o")" "- ブランチ: main"

  # ブランチ名・ファイル名の特殊文字でコマンド注入・表示崩れが起きないこと
  SB="$W/ss-inject"; mkrepo "$SB"
  BN='feat/$(touch${IFS}pwned1)-`touch${IFS}pwned2`->pwned3-|-&'
  ( cd "$SB" && git checkout -q -b "$BN" ) >/dev/null 2>&1
  ssrun "$SB"
  a_eq "SS: 特殊文字ブランチ名でも exit 0"               "$sexit" 0
  a_eq "SS: 特殊文字ブランチ名をそのまま表示（展開しない）" "$(printf '%s\n' "$sout" | grep '^- ブランチ: ')" "- ブランチ: $BN"
  if [ -e "$SB/pwned1" ] || [ -e "$SB/pwned2" ] || [ -e "$SB/pwned3" ]; then r=injected; else r=safe; fi
  a_eq "SS: ブランチ名からコマンド注入されない"          "$r" safe
  ( cd "$SB" && git checkout -q -b '機能/テスト-"quoted"' ) >/dev/null 2>&1
  ssrun "$SB"
  a_eq "SS: 日本語＋引用符のブランチ名をそのまま表示"    "$(printf '%s\n' "$sout" | grep '^- ブランチ: ')" '- ブランチ: 機能/テスト-"quoted"'
  printf 'x\n' > "$SB/x\$(touch\${IFS}pwnedf)y.txt"
  ssrun "$SB"
  a_has "SS: 特殊文字ファイル名をそのまま表示"           "$sout" '?? x$(touch${IFS}pwnedf)y.txt'
  if [ -e "$SB/pwnedf" ]; then r=injected; else r=safe; fi
  a_eq "SS: ファイル名からコマンド注入されない"          "$r" safe
  a_eq "SS: 特殊文字ファイル名でも exit 0"               "$sexit" 0

  # stdin の扱い（SessionStart はフック JSON を stdin で渡す。読まなくても壊れないこと）
  printf '{"session_id":"x","source":"startup"}' | CLAUDE_PROJECT_DIR="$SD" bash "$SS" >/dev/null 2>&1
  a_eq "SS: stdin に JSON を渡しても exit 0"             "$?" 0
  head -c 100000 /dev/zero | tr '\0' 'a' | CLAUDE_PROJECT_DIR="$SD" bash "$SS" >/dev/null 2>&1
  a_eq "SS: 巨大な stdin でも exit 0（SIGPIPE で落ちない）" "$?" 0

  rm -rf "$W"
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "test-hooks: 失敗" >&2
  exit 1
fi
echo "test-hooks: すべて合格"
