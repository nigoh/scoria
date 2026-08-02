#!/usr/bin/env bash
# @file scripts/test-guard-git.sh
# @brief guard-git.sh の敵対的テスト（表駆動・直交組み合わせ）。
# @description
#   guard-git.sh の敵対的テスト（表駆動）。scripts/test-hooks.sh の guard-git セクションを包含し、
#   コマンド形 × 前置 × force 形 × 保護 ref 到達形 × リモート × カレントブランチ × 破損入力を
#   直交的に組み合わせて検査する。
#
#   契約（このファイルが固定する振る舞い）:
#     1. 実際に git が起動される位置に `git push` が現れ、かつ force / 全ブランチ / 保護 ref /
#        保護ブランチ上のカレント push のいずれかに該当するなら exit 2（ブロック）。
#     2. 前方一致（main-backup, mainline, feature/main …）や push でない文言は exit 0（誤爆しない）。
#     3. カレントブランチが判定できない（detached HEAD / リポジトリ外）状態で push 先未指定なら
#        fail-closed（ブロック）。情報欠落を許可に倒さない。
#     4. JSON パーサのバックエンド（jq / python3 / sed フォールバック）が違っても同じ判定になる。
#
#   実 git コマンドは一切実行しない（擬似 JSON を stdin に流すだけ）。ブランチ依存の検証は
#   mktemp -d の隔離リポジトリで行い、コミットも作らない（symbolic-ref / HEAD 直書きで代用）。
# @exitcode 0 全ケース合格
# @exitcode 1 いずれかのケースが不合格（git 不在によるスキップも不合格として扱う）
# @stdout ケースごとの PASS 行とアサーション数
# @stderr 不合格ケースの FAIL 行
set -u

cd "$(dirname "$0")/.." || exit 1

G="$PWD/.claude/hooks/guard-git.sh"
[ -f "$G" ] || { echo "FAIL: $G が見つからない" >&2; exit 1; }

fail=0
count=0
sec="-"

# JSON 文字列としてエスケープする
# @description コマンド文字列を JSON 文字列値として安全に埋め込める形にエスケープする
#   （バックスラッシュ・引用符・改行・タブ）。
# @internal
# @arg $1 string エスケープ対象の文字列
# @stdout エスケープ済みの文字列
jsonesc() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

# @description 期待値と実際値を突き合わせ、結果を記録する（全アサーションの共通出口）。
# @internal
# @arg $1 int 期待する終了コード
# @arg $2 int 実際の終了コード
# @arg $3 string ケースの説明
# @set count int アサーション数を1増やす
# @set fail int 不一致なら 1
report() { # $1=期待 $2=実際 $3=説明
  count=$((count + 1))
  if [ "$2" = "$1" ]; then
    echo "PASS: [$sec] $3"
  else
    echo "FAIL: [$sec] $3 (want=$1 got=$2)" >&2
    fail=1
  fi
}

# t <期待exit> <コマンド文字列> [補足]
# @description コマンド文字列を擬似ツールコール JSON に包んで guard-git に流し、判定を検証する。
# @internal
# @arg $1 int 期待する終了コード（2=ブロック / 0=許可）
# @arg $2 string 検査する git コマンド文字列
# @arg $3 string 補足説明（省略可。出力に … で連結される）
# @set fail int 不一致なら 1
t() {
  local want=$1 cmd=$2 note=${3:-} got
  printf '{"tool_input":{"command":"%s"}}' "$(jsonesc "$cmd")" | bash "$G" >/dev/null 2>&1
  got=$?
  report "$want" "$got" "${cmd}${note:+ … $note}"
}

# traw <期待exit> <生JSON(printf %b 解釈)> [説明]（省略時は JSON 自体を説明に使う）
# @description 生の（壊れた／特殊な）JSON をそのまま guard-git に流し、判定を検証する。
#   破損入力に対するフェイルセーフの向きを固定するために使う。
# @internal
# @arg $1 int 期待する終了コード
# @arg $2 string stdin に流す生 JSON（printf %b で解釈される）
# @arg $3 string ケースの説明（省略時は JSON 自体を使う）
# @set fail int 不一致なら 1
traw() {
  local want=$1 json=$2 desc=${3:-$2} got
  printf '%b' "$json" | bash "$G" >/dev/null 2>&1
  got=$?
  report "$want" "$got" "$desc"
}

# ti <ディレクトリ> <期待exit> <コマンド> [補足] : 隔離リポジトリを cwd/CLAUDE_PROJECT_DIR にして実行
# @description 隔離リポジトリ（カレントブランチが既知）を cwd / CLAUDE_PROJECT_DIR にして guard-git を実行する。
#   カレントブランチ依存の判定を実リポジトリの状態に左右されず検証するため。
# @internal
# @arg $1 path 隔離リポジトリのディレクトリ
# @arg $2 int 期待する終了コード
# @arg $3 string 検査する git コマンド文字列
# @arg $4 string 補足説明（省略可）
# @set fail int 不一致なら 1
ti() {
  local dir=$1 want=$2 cmd=$3 note=${4:-} got
  printf '{"tool_input":{"command":"%s"}}' "$(jsonesc "$cmd")" \
    | ( cd "$dir" && CLAUDE_PROJECT_DIR="$dir" bash "$G" ) >/dev/null 2>&1
  got=$?
  report "$want" "$got" "${cmd}${note:+ … $note}"
}

# tp <PATH> <ディレクトリ> <期待exit> <コマンド> <説明> : パーサバックエンドを絞って実行
# @description PATH を絞って JSON パーサのバックエンド（jq / python3 / パーサ無し）を固定し、guard-git を実行する。
#   どのバックエンドでも同一 verdict になること（ツール次第で判定が変わらないこと）の検証に使う。
# @internal
# @arg $1 string 実行時の PATH
# @arg $2 path 隔離リポジトリのディレクトリ
# @arg $3 int 期待する終了コード
# @arg $4 string 検査する git コマンド文字列
# @arg $5 string ケースの説明
# @set fail int 不一致なら 1
tp() {
  local pathval=$1 dir=$2 want=$3 cmd=$4 desc=$5 got
  printf '{"tool_input":{"command":"%s"}}' "$(jsonesc "$cmd")" \
    | ( cd "$dir" && PATH="$pathval" CLAUDE_PROJECT_DIR="$dir" bash "$G" ) >/dev/null 2>&1
  got=$?
  report "$want" "$got" "$desc"
}

# ---------------------------------------------------------------------------
sec="A コマンド形"
# 空白・タブ・改行・チェーン・グループ・コマンド置換。保護 ref 版（2）と非保護版（0）を対にする。
# 非保護版は位置引数を2つ持たせ、カレントブランチ検査(3)に落ちないようにして決定論性を保つ。
t 2 'git push origin main'
t 0 'git push origin claude/x'
t 2 'git  push   origin    main'                     '多重スペース'
t 0 'git  push   origin    claude/x'                 '多重スペース'
t 2 "git${TAB:=$'\t'}push${TAB}origin${TAB}main"     'タブ区切り'
t 0 "git${TAB}push${TAB}origin${TAB}claude/x"        'タブ区切り'
t 2 "git ${TAB} push ${TAB}${TAB}origin  ${TAB} main" '空白とタブの混在'
t 0 "git ${TAB} push ${TAB}${TAB}origin  ${TAB} claude/x" '空白とタブの混在'
t 0 'git \t push \t origin \t main'                  'バックスラッシュ展開後は push でない'
t 2 'git add -A && git push origin main'             'AND チェーン'
t 0 'git add -A && git push origin claude/x'         'AND チェーン'
t 2 'git add -A ; git push origin master'            'セミコロン'
t 2 'git fetch || git push origin main'              'OR チェーン'
t 2 'echo x | git push origin main'                  'パイプ'
t 2 $'git status\ngit push origin main'              '改行区切り'
t 0 $'git status\ngit push origin claude/x'          '改行区切り'
t 2 'git push origin \'$'\n''main'                   '行継続で分断した main'
t 2 'git push \'$'\n''--force origin claude/x'       '行継続で分断した --force'
t 2 '(cd /repo && git push origin main)'             'サブシェル (…)'
t 2 '(git push --force origin claude/x)'             'サブシェル先頭の force'
t 0 '(cd /repo && git push origin claude/x)'         'サブシェル（非保護）'
t 2 'echo $(git push origin main)'                   'コマンド置換 $(…)'
t 2 'x=$(git push --force origin claude/x)'          'コマンド置換の代入'
t 2 'x=`git push origin main`'                       'バッククォート'
t 2 '{ git push origin main; }'                      'ブレースグループ'
t 2 'if true; then git push origin main; fi'         'if/then'
t 2 'while true; do git push --force origin claude/x; done' 'while/do'
t 2 '! git push origin main'                         '否定 !'
t 2 'git push origin main > /dev/null'               'リダイレクト付き'
t 2 'git push origin main 2>&1 | tee log'            'リダイレクト＋パイプ'
t 0 'git push origin claude/x > /dev/null'           'リダイレクト付き（非保護）'
t 2 'cd /repo && git push origin refs/heads/master && echo done' '前後にコマンド'

# ---------------------------------------------------------------------------
sec="B 前置（env / git グローバルオプション）"
# 各前置について「保護 ref なら 2 / 非保護なら 0」を対で検査する（前置で判定が脱線しないこと）。
PREFIXES=(
  'git push'
  'GIT_TRACE=1 git push'
  'GIT_TRACE=1 GIT_CURL_VERBOSE=1 git push'
  'GIT_SSH_COMMAND="ssh -i k" git push'
  'A=1 GIT_SSH_COMMAND="ssh -i /k/id rsa" B=2 git push'
  "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' git push"
  'env git push'
  'env GIT_TRACE=1 git push'
  'env -i GIT_TRACE=1 git push'
  'env -u GIT_DIR git push'
  'sudo git push'
  'command git push'
  'nohup git push'
  'time git push'
  'exec git push'
  'git -C /tmp/x push'
  'git -C /tmp/x -c user.name=x push'
  'git -c user.name=x push'
  'git -c user.name="A B" push'
  "git -c core.sshCommand='ssh -i k' push"
  'git -c a.b=c=d push'
  'git -c a.b="c=d e" push'
  'git --git-dir=/tmp/x/.git push'
  'git --git-dir /tmp/x/.git push'
  'git --work-tree=/tmp/x push'
  'git --namespace=ns push'
  'git --exec-path=/usr/libexec push'
  'git --no-pager push'
  'git --bare push'
  'git -p push'
  'git --literal-pathspecs push'
  'git --no-optional-locks push'
  'GIT_TRACE=1 env git -C /tmp/x -c user.name="A B" --no-pager push'
)
for p in "${PREFIXES[@]}"; do
  t 2 "$p origin main"
  t 0 "$p origin claude/x"
done

# ---------------------------------------------------------------------------
sec="C force 系"
# force フラグは push の前後どちらに置いてもブロックされること（ref は非保護で固定）。
FORCE_FLAGS=(
  '--force'
  '-f'
  '--force-with-lease'
  '--force-with-lease=claude/x'
  '--force-with-lease=refs/heads/claude/x:abc123'
  '--force-if-includes'
  '-fu'
  '-uf'
  '-fq'
  '-qf'
  '-vf'
  '-fv'
  '-qfu'
)
for f in "${FORCE_FLAGS[@]}"; do
  t 2 "git push $f origin claude/x"        'force フラグは push 直後'
  t 2 "git push origin claude/x $f"        'force フラグは末尾'
done
t 2 'git push --force-with-lease --force-if-includes origin claude/x'
t 2 'git push origin +claude/x'                       '+refspec'
t 2 'git push origin +HEAD:claude/x'                  '+refspec (HEAD)'
t 2 'git push origin +refs/heads/x:refs/heads/y'      '+refspec (完全修飾)'
t 2 'git push origin claude/x +claude/y'              '2つ目の refspec が +'
t 2 'git push "--force" origin claude/x'              'クォートで隠した --force'
t 2 "git push '-f' origin claude/x"                   'クォートで隠した -f'
t 2 'git push --force origin main'                    'force かつ保護 ref'
# force でない短縮/長形式は許可（過剰ブロックしない）
NONFORCE=(
  '-u' '-q' '-v' '-n' '-qu' '-uq' '-vq' '-nu'
  '--quiet' '--verbose' '--set-upstream' '--tags' '--follow-tags' '--atomic'
  '--dry-run' '--no-verify' '--thin' '--porcelain' '--no-force-if-includes'
  '--recurse-submodules=check' '--receive-pack=git-receive-pack'
)
for f in "${NONFORCE[@]}"; do
  t 0 "git push $f origin claude/x" 'force でないオプションは許可'
done
t 0 'git push origin claude/feature+x'                'トークン途中の + は force ではない'
t 0 'git push origin claude/x --push-option=fast'     'push-option の f は force ではない'

# ---------------------------------------------------------------------------
sec="D 保護 ref への到達形"
REFS=(
  'main' 'master'
  'refs/heads/main' 'refs/heads/master'
  'heads/main' 'heads/master'
  'HEAD:main' 'HEAD:master'
  'HEAD:refs/heads/main' 'HEAD:refs/heads/master'
  'HEAD:heads/main' 'HEAD:heads/master'
  'claude/x:main' 'claude/x:refs/heads/master'
  ':main' ':master'
  '+main' '+claude/x:main'
  'main:main' 'refs/heads/main:refs/heads/main'
  '"main"' "'master'" 'ma"in"' "'refs/heads/'main"
  'HEAD:"main"'
)
for r in "${REFS[@]}"; do
  for remote in origin upstream; do
    t 2 "git push $remote $r"
  done
done
t 2 'git push origin claude/x main'                   '複数 refspec の2つ目が main'
t 2 'git push origin main claude/x'                   '複数 refspec の1つ目が main'
t 2 'git push origin --delete main'                   'リモートブランチ削除'
t 2 'git push origin -d master'                       'リモートブランチ削除（短縮）'
t 2 'git push --delete origin main'
t 2 'git push -u origin main'
t 2 'git push origin main --dry-run'                  'dry-run でもブロック（fail-closed）'
t 2 'git push origin main:main --no-verify'

# ---------------------------------------------------------------------------
sec="E 誤爆防止（許可されるべき）"
SAFE_REFS=(
  'main-backup' 'main_backup' 'main.old' 'mainline' 'main2' 'submain' 'remain'
  'feature/main' 'claude/main' 'topic/master' 'master-old' 'mastermind' 'premaster'
  'claude/foo' 'feat/x' 'release/1.0' 'main-2' 'xmain' 'MAIN' 'Master'
)
for r in "${SAFE_REFS[@]}"; do
  t 0 "git push origin $r"
done
t 0 'git push origin feature/main:feature/main'       'refspec 両側とも非保護'
t 0 'git push origin HEAD:claude/x'
t 0 'git push origin claude/x:refs/heads/claude/x'
t 0 'git pushx origin main'                           'push でないサブコマンド'
t 0 'git push-all origin main'                        'push でないサブコマンド'
t 0 'gitx push origin main'                           'git でないコマンド'
t 0 'mygit push origin main'                          'git でないコマンド'
t 0 'echo git push failed'                            'echo の引数'
t 0 'echo "git push --force origin main"'             'クォートした文言'
t 0 'git commit -m "docs: explain git push --force policy"'
t 0 'git commit -m "fix: block git push origin main in guard"'
t 0 'git log --oneline | grep "git push origin main"'
t 0 'git fetch origin main'                           'push でないサブコマンド'
t 0 'git checkout main'
t 0 'git merge origin/main'
t 0 'git branch -d main'
t 0 'ls -la'
t 0 'grep -r "push --force" .claude'
# 既知の許容誤検知（fail-closed）: コメント内の main も引数文字列扱いでブロックされる。
# コメント除去は「行継続と結合した後の # 以降」を落として真の push を隠す経路を生むため行わない。
t 2 'git push origin claude/x # push to main later'   'コメント内の main は fail-closed で誤ブロック（許容）'
t 0 'git push origin claude/x # topic branch only'    'main を含まないコメントは許可'

# ---------------------------------------------------------------------------
sec="F 全ブランチ push"
t 2 'git push --all'
t 2 'git push --all origin'
t 2 'git push origin --all'
t 2 'git push --mirror'
t 2 'git push --mirror origin'
t 2 'git push origin --mirror'
t 2 'git push --all --dry-run origin'
t 2 'GIT_TRACE=1 git -C /tmp/x push --all origin'
t 2 'git push --mirror https://github.com/x/y.git'
t 2 'cd /repo && git push --all origin'
t 0 'git push origin claude/all'                      '--all に似たブランチ名'
t 0 'git push origin claude/x --push-option=all'
t 0 'git push --recurse-submodules=on-demand origin claude/x'

# ---------------------------------------------------------------------------
sec="G リモート指定"
REMOTES=(
  'origin' 'upstream' 'gitlab' 'fork'
  'https://github.com/x/y.git' 'git@github.com:x/y.git'
  'ssh://git@github.com/x/y.git' 'git://h/x.git' '/srv/git/x.git' '../other'
)
for rm in "${REMOTES[@]}"; do
  t 2 "git push $rm main"
  t 0 "git push $rm claude/x"
done

# ---------------------------------------------------------------------------
sec="H カレントブランチ検査（隔離リポジトリ）"
if command -v git >/dev/null 2>&1; then
  WORK=$(mktemp -d)
  # @description カレントブランチが既知の隔離 git リポジトリを作る。コミットは作らず
  #   symbolic-ref（ブランチ指定時）または .git/HEAD 直書き（detached 再現）で代用する。
  # @internal
  # @arg $1 string 作成するディレクトリ名（$WORK 配下）
  # @arg $2 string ブランチ名（省略時は detached HEAD にする）
  # @stdout 作成したリポジトリの絶対パス
  mkrepo() { # $1=ディレクトリ名 $2=ブランチ名（省略時 detached）
    local d="$WORK/$1"
    mkdir -p "$d"
    ( cd "$d" && git init -q ) >/dev/null 2>&1
    if [ -n "${2:-}" ]; then
      ( cd "$d" && git symbolic-ref HEAD "refs/heads/$2" ) >/dev/null 2>&1
    else
      printf '%s\n' '0123456789abcdef0123456789abcdef01234567' > "$d/.git/HEAD"
    fi
    printf '%s' "$d"
  }
  RMAIN=$(mkrepo main main)
  RMASTER=$(mkrepo master master)
  RFEAT=$(mkrepo feat claude/feat)
  RDETACHED=$(mkrepo detached)
  RPLAIN="$WORK/plain"; mkdir -p "$RPLAIN"   # git リポジトリではないディレクトリ

  # main 上: push 先未指定はすべてブロック（リモート名のホワイトリストに依存しない）
  ti "$RMAIN" 2 'git push'
  ti "$RMAIN" 2 'git push origin'
  ti "$RMAIN" 2 'git push upstream'
  ti "$RMAIN" 2 'git push gitlab'
  ti "$RMAIN" 2 'git push -u origin'
  ti "$RMAIN" 2 'git push --quiet'
  ti "$RMAIN" 2 'git push origin HEAD'                  '裸 HEAD はカレント参照'
  ti "$RMAIN" 2 'git push origin @'                     '裸 @ はカレント参照'
  ti "$RMAIN" 2 'git push --repo=origin'
  ti "$RMAIN" 2 'git push git@github.com:x/y.git'       'URL の : をターゲットと誤認しない'
  ti "$RMAIN" 2 'git push https://github.com/x/y.git'
  ti "$RMAIN" 2 'git push -o ci.skip origin'            'push-option の値をリモートと誤認しない'
  ti "$RMAIN" 2 'git push --push-option=ci.skip origin'
  ti "$RMAIN" 2 'GIT_TRACE=1 git -C /tmp/x push'
  ti "$RMAIN" 2 'git push origin --all-of-them'         '未知のオプションは位置引数でない'
  ti "$RMAIN" 2 'cd /elsewhere && git push'
  ti "$RMAIN" 0 'git push origin claude/x'              '明示ターゲットは許可'
  ti "$RMAIN" 0 'git push origin HEAD:claude/x'
  ti "$RMAIN" 0 'git status'
  ti "$RMAIN" 0 'git pushx'
  # master 上
  ti "$RMASTER" 2 'git push'
  ti "$RMASTER" 2 'git push origin'
  ti "$RMASTER" 2 'git push origin HEAD'
  ti "$RMASTER" 0 'git push origin claude/x'
  # 非保護ブランチ上: カレント push は許可、他の禁止形は依然ブロック
  ti "$RFEAT" 0 'git push'
  ti "$RFEAT" 0 'git push origin'
  ti "$RFEAT" 0 'git push gitlab'
  ti "$RFEAT" 0 'git push origin HEAD'
  ti "$RFEAT" 0 'git push origin @'
  ti "$RFEAT" 0 'git push origin --all-of-them'         '--all/--mirror 正規表現の誤爆なし'
  ti "$RFEAT" 0 'git push -o ci.skip origin'
  ti "$RFEAT" 0 'git push --repo=origin'
  ti "$RFEAT" 2 'git push --force'
  ti "$RFEAT" 2 'git push -f'
  ti "$RFEAT" 2 'git push --all'
  ti "$RFEAT" 2 'git push --mirror'
  ti "$RFEAT" 2 'git push origin main'
  ti "$RFEAT" 2 'git push origin HEAD:master'
  # detached HEAD / 非リポジトリ: カレントブランチ判定不能 → fail-closed
  ti "$RDETACHED" 2 'git push'                          'detached HEAD は安全側でブロック'
  ti "$RDETACHED" 2 'git push origin'
  ti "$RDETACHED" 2 'git push origin HEAD'
  ti "$RDETACHED" 0 'git push origin claude/x'          '明示ターゲットなら許可'
  ti "$RDETACHED" 0 'ls -la'
  ti "$RPLAIN" 2 'git push'                             'リポジトリ外も判定不能 → ブロック'
  ti "$RPLAIN" 0 'git push origin claude/x'
  # CLAUDE_PROJECT_DIR が存在しない（cd 失敗）→ 判定不能 → fail-closed
  printf '{"tool_input":{"command":"git push"}}' \
    | ( cd "$RPLAIN" && CLAUDE_PROJECT_DIR="$WORK/nonexistent" bash "$G" ) >/dev/null 2>&1
  report 2 "$?" 'CLAUDE_PROJECT_DIR が存在しない場合も fail-closed'

  # -------------------------------------------------------------------------
  sec="I パーサバックエンド等価性"
  # jq / python3 / どちらも無い（sed フォールバック）で同じ判定になること。
  BIN="$WORK/bin"; mkdir -p "$BIN"
  for c in bash cat awk tr sed cut grep git env dirname basename; do
    p=$(command -v "$c" 2>/dev/null) && ln -sf "$p" "$BIN/$c"
  done
  PATH_JQ="$BIN:$PATH"
  PATH_PY="$BIN"
  [ -n "$(command -v python3 2>/dev/null)" ] && ln -sf "$(command -v python3)" "$BIN/python3"
  PATH_NONE="$WORK/bin-none"; mkdir -p "$PATH_NONE"
  for c in bash cat awk tr sed cut grep git env dirname basename; do
    p=$(command -v "$c" 2>/dev/null) && ln -sf "$p" "$PATH_NONE/$c"
  done
  EQ_CMDS=(
    '2|git push origin main'
    '2|git push --force origin claude/x'
    '2|GIT_SSH_COMMAND="ssh -i k" git push origin main'
    '2|git -c user.name="A B" push origin refs/heads/master'
    '2|git add -A && git push origin HEAD:main'
    '2|git push --all origin'
    '2|(cd /r && git push origin main)'
    '2|git push'
    '0|git push origin claude/x'
    '0|git push origin main-backup'
    '0|echo git push failed'
    '0|git commit -m "docs: git push --force"'
    '0|ls -la'
    '0|git push -u origin claude/foo'
  )
  for e in "${EQ_CMDS[@]}"; do
    w=${e%%|*}; c=${e#*|}
    tp "$PATH_JQ"   "$RMAIN" "$w" "$c" "jq 経路: $c"
    tp "$PATH_PY"   "$RMAIN" "$w" "$c" "python3 経路（jq 無し）: $c"
    tp "$PATH_NONE" "$RMAIN" "$w" "$c" "パーサ無し経路（sed）: $c"
  done
  rm -rf "$WORK"
else
  echo "SKIP: git が無いためカレントブランチ検査とバックエンド等価性を省略" >&2
  fail=1
fi

# ---------------------------------------------------------------------------
sec="J 破損入力・巨大入力（フェイルセーフの向き）"
# JSON が壊れている/コマンドが取れない場合は現行契約どおりフェイルオープン（最終防衛線は
# settings.json の permissions.deny と GitHub ブランチ保護）。ここは「向き」を明示的に固定する。
traw 0 '{}'                                            '空 JSON'
traw 0 '{"tool_input":{}}'                             'command キー欠落'
traw 0 '{"tool_input":{"command":""}}'                 '空コマンド'
traw 0 '{"tool_name":"Bash"}'                          'tool_input 欠落'
traw 0 '{"tool_input":{"command":'                     '途中で切れた JSON'
traw 0 'not json at all'                               'JSON でない'
traw 0 '[]'                                            '配列トップレベル'
traw 0 'null'                                          'null トップレベル'
traw 0 '{"tool_input":"git push origin main"}'         'tool_input が文字列'
traw 0 '{"tool_input":{"command":null}}'               'command が null'
traw 0 '{"tool_input":{"command":123}}'                'command が数値'
traw 0 '{"tool_input":{"command":["git","push","origin","main"]}}' 'command が配列'
traw 0 '{"tool_input":{"command":{"a":"git push origin main"}}}'   'command がオブジェクト'
traw 0 '{"tool_input":{"command":"   "}}'              '空白のみ'
traw 0 '{"tool_input":{"command":"\\n\\n"}}'           '改行のみ'
# 制御文字・不正 UTF-8 が混ざっても、実際に main へ届く形は取りこぼさない
traw 2 '{"tool_input":{"command":"git push origin main\\u0020"}}'  '末尾に空白エスケープ'
traw 2 '{"tool_input":{"command":"\\tgit push origin main"}}'      '先頭タブ'
traw 2 '{"tool_input":{"command":"git push origin \\"main\\""}}'   'クォート済み main'
traw 2 '{"tool_input":{"command":"git\\tpush\\torigin\\tmain"}}'   'タブ区切り'
traw 0 '{"tool_input":{"command":"git push origin main\xff"}}'     '不正 UTF-8 が付いた別名 ref'
traw 0 '{"tool_input":{"command":"git push origin \xffmain"}}'     '不正 UTF-8 が付いた別名 ref'
# 巨大入力でもタイムアウト/取りこぼしをしない
BIG=$(awk 'BEGIN{ s=""; for(i=0;i<4000;i++) s=s "abcdefghij"; print s }')
t 2 "echo $BIG && git push origin main"  '巨大入力（40KB）の末尾の main push'
t 0 "echo $BIG && git push origin claude/x" '巨大入力（40KB・非保護）'
BIGSEG=$(awk 'BEGIN{ s=""; for(i=0;i<800;i++) s=s "echo x; "; print s }')
t 2 "$BIGSEG git push origin main" '多数セグメント（800）の末尾の main push'

# ---------------------------------------------------------------------------
sec="K 既存契約の再現（test-hooks.sh の guard-git ケース）"
t 2 'git push --force origin feature'
t 2 'git push --force-with-lease origin feature'
t 2 'git push -f origin feature'
t 2 'git push origin +feature'
t 2 'git push origin +feature:main'
t 2 'git push origin main'
t 2 'git push origin master'
t 2 'git push origin feature:main'
t 2 'git push origin HEAD:main'
t 2 'git push origin :main'
t 2 'git  push  --force origin feature'
t 2 'git add -A && git push origin main'
t 2 'git push origin "main"'
t 2 'git -C /tmp/x push origin main'
t 2 'GIT_TRACE=1 git push origin main'
t 2 'git -c user.name=x push --force origin feature'
t 0 'git push -u origin claude/foo'
t 0 'git push origin main-backup'
t 0 'ls -la'
t 0 'git pushx origin main'
t 0 'echo git push failed'
t 0 'git commit -m "docs: explain git push --force policy"'
traw 0 '{}'
t 2 'GIT_SSH_COMMAND="ssh -i k" git push origin main'
t 2 'git -c core.sshCommand="ssh -i k" push origin main'
t 2 'GIT_SSH_COMMAND="ssh -i k" git push --force origin feature'
t 2 'git push origin HEAD:refs/heads/main'
t 2 'git push origin refs/heads/main'
t 0 'git push origin feature/main'
t 2 'git push origin \'$'\n''main'
t 2 'git push origin --all'
t 2 'git push --all origin'
t 2 'git push --mirror origin'
t 2 'git push -fu origin feature'
t 2 'git push -uf origin feature'
t 2 'git push -fq origin feature'
t 0 'git push -qu origin claude/foo'
t 2 'git push origin HEAD:heads/main'
t 2 'git push origin heads/master'

echo ""
echo "アサーション数: $count"
if [ "$fail" -ne 0 ]; then
  echo "test-guard-git: 失敗" >&2
  exit 1
fi
echo "test-guard-git: すべて合格"
