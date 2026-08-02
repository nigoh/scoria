#!/usr/bin/env bash
# @file .claude/hooks/guard-git.sh
# @brief PreToolUse(Bash) hook: 保護ブランチへの push と force push を決定論的にブロックする。
# @description
#   ルール本文: CLAUDE.md「絶対原則」/ ADR-0004。settings.json の permissions.deny と
#   GitHub ブランチ保護が最終防衛線。
#   exit 2 = ブロック（stderr が Claude に渡る）。
#
#   ブロックする形（すべて実シェルで保護 ref に解決される）:
#     1) force push（--force / --force-with-lease / --force-if-includes / -f・束ねた短縮フラグ / +refspec）
#     1b) 全ブランチ push（--all / --mirror。main/master を巻き込むため）
#     2) push 先に保護ブランチを指定する形（main / feature:main / HEAD:main / :main /
#        refs/heads/main / heads/main）
#     3) push 先未指定 かつ カレントが保護ブランチ、または カレントが判定不能
#
#   フェイルセーフの向き:
#   - JSON が壊れている / command キーが無い場合はフェイルオープン（判定対象が存在しない）。
#     ただし jq も python3 も無い環境では awk の簡易 JSON 抽出にフォールバックし、素通りさせない。
#   - カレントブランチが判定できない（detached HEAD / リポジトリ外 / git 不在）状態での
#     push 先未指定 push は **フェイルクローズ**（ブロック）。情報欠落を許可に倒さない。
#
#   既知の限界（意図的な設計。最終防衛線は permissions.deny と GitHub ブランチ保護）:
#   - スクリプト経由（bash -c '...' や sh ファイル実行、クォート内に隠した push）は素通りする
#   - コマンド文字列中の cd で別リポジトリへ移った場合、ブランチ判定は CLAUDE_PROJECT_DIR 基準のまま
#   - クォートは中身を残して剥がすため、echo 等の引数文字列内やコメント（#）内に push コマンド形が
#     完全一致で含まれると誤ブロックすることがある（フェイルクローズ＝安全側）
#   - `-o main` のように push-option の分離値が保護名リテラルと一致すると誤ブロックする
#     （フェイルクローズ＝安全側。オプション値の除去は逆に真のバイパスを生むため行わない）
#
# @stdin PreToolUse フックの JSON。`.tool_input.command`（実行しようとしている Bash コマンド文字列）
#   だけを判定材料にする。jq → python3 → awk の順にフォールバックして抽出する
# @stderr ブロック理由と「代わりに何をすべきか」（Claude に渡り、次の行動を誘導する）
# @exitcode 0 許可（push でない／保護 ref に届かない／command 抽出不能）
# @exitcode 2 ブロック（force push・全ブランチ push・保護ブランチへの push・判定不能な push）
# @see scripts/test-guard-git.sh 契約テスト（保護 ref に届く全 push 形をブロックする表）
set -u

PROTECTED_BRANCHES="main|master"

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true

input=$(cat)

# tool_input.command を抽出（jq → python3 → awk の順でフォールバック）
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
else
  # jq も python3 も無い環境で全 push を素通りさせない（fail-open 防止）。
  # "command" の値を JSON 文字列としてエスケープを戻しつつ素朴に切り出す。
  cmd=$(printf '%s' "$input" | awk '
    { all = all $0 "\n" }
    END {
      i = index(all, "\"command\""); if (i == 0) exit
      s = substr(all, i + 9); n = length(s); k = 1
      while (k <= n && substr(s,k,1) ~ /[: \t\n]/) k++
      if (substr(s,k,1) != "\042") exit
      k++
      while (k <= n) {
        c = substr(s,k,1)
        if (c == "\\") {
          d = substr(s,k+1,1)
          if (d == "n") out = out "\n"
          else if (d == "t") out = out "\t"
          else if (d == "r") out = out "\r"
          else if (d == "u") { out = out " "; k += 4 }   # \uXXXX は空白扱い（隠蔽を許さない側）
          else out = out d
          k += 2; continue
        }
        if (c == "\042") break
        out = out c; k++
      }
      print out
    }' 2>/dev/null)
fi

[ -z "${cmd:-}" ] && exit 0

# バックスラッシュ行継続（\ + 改行）を結合する。結合しないとセグメント分割が改行で切れ、
# `git push origin \⏎main`（実シェルでは `git push origin main`）の後半が検査対象外になる。
cmd=${cmd//\\$'\n'/}

# クォートを中身を残して剥がす（git push origin "main" 形の隠蔽を防ぐ）。
# ただしクォート内の空白は保護（0x1F へ退避）してからトークン分割する。素朴に空白を残すと
# `GIT_SSH_COMMAND="ssh -i k" git push origin main` のようにクォート値内の空白で
# トークンが割れ、env 代入や `-c` の値がずれて git/push 判定が脱線し保護 push を取りこぼす。
# 併せてクォート外のバックスラッシュエスケープ（`\main` → `main`）と ANSI-C クォートの
# 先頭 `$`（`$'main'` → `main`）も落とす。どちらも実シェルでは保護 ref に解決されるため。
cmd_stripped=$(printf '%s' "$cmd" | awk '
  { out=""; q=""; n=length($0)
    for(i=1;i<=n;i++){ c=substr($0,i,1)
      if(q==""){ if(c=="\\"){ i++; if(i<=n) out=out substr($0,i,1); continue }
                 if(c=="$"){ d=substr($0,i+1,1); if(d=="\047"||d=="\042") continue }
                 if(c=="\047"||c=="\042"){ q=c; continue } out=out c }
      else { if(c==q){ q=""; continue }
             if(c==" "||c=="\t"){ out=out "\037" } else out=out c } }
    print out }' | tr -s '[:blank:]' ' ')

# @internal
# @description ブロック理由を stderr に出してフックを終了する（＝ツール実行を止める）。
# @arg $1 string ブロック理由と代替手段の案内（Claude に渡る）
# @stderr 引数の文字列
# @exitcode 2 常に（PreToolUse フックの「ブロック」規約）
block() {
  echo "$1" >&2
  exit 2
}

# @internal
# @description トークン列（空白区切り。クォート内空白は 0x1F へ退避済み）の先頭トークンを返す。
# @arg $1 string トークン列
# @stdout 先頭トークン
# @exitcode 0 常に成功
first_tok() { printf '%s' "$1" | cut -d' ' -f1; }

# @internal
# @description トークン列から先頭トークンを1つ落として返す。残りが無ければ空文字を返す
#   （cut は区切りが無いと入力をそのまま返すため、無限ループ回避に空文字へ潰す）。
# @arg $1 string トークン列
# @stdout 先頭トークンを除いた残り。トークンが1つだけなら空文字
# @exitcode 0 常に成功
drop_tok() {
  local r
  r=$(printf '%s' "$1" | cut -d' ' -f2-)
  [ "$r" = "$1" ] && r=""
  printf '%s' "$r"
}

# ; & | ( ) ` でセグメントに分割し、「git push」がコマンド先頭にあるセグメントだけを検査する。
# 括弧とバッククォートを区切りに含めるのは `(cd x && git push origin main)` や
# `$(git push --force ...)` のようにサブシェル・コマンド置換内で実際に git が起動する形を
# 取りこぼさないため（クォート内の空白は 0x1F 退避済みなので、引数文字列は誤って
# セグメント先頭にならない）。
# （for のリストはループ開始時に一度だけ展開されるため、本体先頭で IFS を戻してよい）
default_ifs=$' \t\n'
IFS=$'\n'
for seg in $(printf '%s' "$cmd_stripped" | tr ';&|()`' '\n'); do
  IFS=$default_ifs
  seg=$(printf '%s' "$seg" | sed -e 's/^ *//' -e 's/ *$//')

  # 先頭の環境変数代入（VAR=val git push ...）・ラッパー語（env/sudo/time …）・制御構文
  # キーワード（then/do/{ …）をスキップし、実際に起動されるコマンド名まで進める
  s=$seg
  env_mode=0
  while [ -n "$s" ]; do
    case "$(first_tok "$s")" in
      [A-Za-z_]*=*) s=$(drop_tok "$s") ;;
      env) env_mode=1; s=$(drop_tok "$s") ;;
      sudo|command|builtin|exec|nohup|time|then|else|elif|do|'!'|'{'|'}') s=$(drop_tok "$s") ;;
      -u|--unset) [ "$env_mode" -eq 1 ] || break; s=$(drop_tok "$s"); s=$(drop_tok "$s") ;;
      -*) [ "$env_mode" -eq 1 ] || break; s=$(drop_tok "$s") ;;
      *) break ;;
    esac
  done
  [ "$(first_tok "$s")" = "git" ] || continue
  s=$(drop_tok "$s")
  # git のグローバルオプション（git -C dir push / git -c k=v push / git --no-pager push 等）を
  # スキップする。サブコマンドより前のダッシュ付きトークンはすべてグローバルオプションなので、
  # 値を取るものだけ2トークン、それ以外は1トークン読み飛ばす（列挙漏れで素通りさせない）。
  while [ -n "$s" ]; do
    case "$(first_tok "$s")" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env|--attr-source)
        s=$(drop_tok "$s"); s=$(drop_tok "$s") ;;
      -*) s=$(drop_tok "$s") ;;
      *) break ;;
    esac
  done
  [ "$(first_tok "$s")" = "push" ] || continue
  rest=$(drop_tok "$s")

  # 1) force push の禁止（--force / --force-with-lease / --force-if-includes / -f / +refspec）
  # 短縮フラグは束ねられる（git は `-fu` を `-f -u` と解釈する）ため、単独の `-f` だけでなく
  # 単ダッシュのクラスタに `f` を含む形（-fu / -uf / -fq …）をすべて弾く。push の短縮オプションで
  # `f` を意味するのは force だけなので誤検知しない。二重ダッシュ側は `--force` に続く文字が
  # `-`/`=`/空白/行末のものを弾く（--force-with-lease=… / --force-if-includes を含む）。
  # `--no-force-if-includes`（force を無効化する側）は `--force` 二重ダッシュに一致しないので許可。
  if printf '%s' "$rest" | grep -Eq -- '--force([-=]|[[:space:]]|$)|(^|[[:space:]])-[A-Za-z0-9]*f[A-Za-z0-9]*([[:space:]]|$)|(^|[[:space:]])\+[^[:space:]]+'; then
    block "ブロック: force push は禁止です（CLAUDE.md 絶対原則）。--force-with-lease や +refspec を含め、履歴の書き換えはユーザーの明示指示が必要です。"
  fi

  # 1b) 全ブランチ push の禁止（--all / --mirror）。これらは push 先の位置引数に依らず
  #     ローカルの全ブランチ（main/master を含む）を push し、--mirror はリモート ref の
  #     削除・巻き戻しまで行う。トピックブランチ + PR 運用では不要。下の 3) は「push 先未指定 かつ
  #     カレントが保護ブランチ」しか見ないため、トピックブランチ上からのこの形を取りこぼす。
  if printf '%s' "$rest" | grep -Eq -- '(^|[[:space:]])--(all|mirror)([[:space:]]|$)'; then
    block "ブロック: git push --all/--mirror は main/master を含む全ローカルブランチを push（--mirror は削除も）します。個別のトピックブランチを明示して push してください。"
  fi

  # 2) 保護ブランチを push 先に指定する形の禁止（main / feature:main / HEAD:main / :main /
  #    完全修飾 refs/heads/main / 短縮 heads/main）。`(refs/heads/|heads/)?` を許容して境界に
  #    `/` を足さない（`/` を境界にすると feature/main のような非保護ブランチを誤ブロックするため）。
  #    git は dst 側の `heads/main` を既存 refs/heads/main へ解決するため heads/ 前置も弾く必要がある。
  if printf '%s' "$rest" | grep -Eq "([[:space:]]|:)(refs/heads/|heads/)?(${PROTECTED_BRANCHES})([[:space:]]|$)"; then
    block "ブロック: 保護ブランチ (${PROTECTED_BRANCHES}) への push は禁止です。トピックブランチへ push し、PR 経由でマージしてください。"
  fi

  # 3) push 先の指定が無い（カレントブランチを push する）場合、保護ブランチ上なら禁止
  # push 先の明示的なブランチ指定があるか判定する。リモート名は origin/upstream に
  # 限らないため、名前でホワイトリストせず「位置引数の数」で見る: 1つ目の位置引数は
  # リモート（名前でも URL でもよい）、2つ目以降がブランチ指定。これで
  # `git push gitlab`（= カレントブランチを gitlab へ push）も `git push git@h:x.git`
  # （URL の `:` を refspec と誤認しない）も未指定として正しく検査対象になる。
  has_target=0
  positional=0
  skipval=0
  for tok in $rest; do
    if [ "$skipval" -eq 1 ]; then skipval=0; continue; fi
    case "$tok" in
      -o|--push-option|--repo|--exec|--receive-pack) skipval=1; continue ;;  # 分離値はリモートでない
      -*) continue ;;                                                        # オプションは無視
    esac
    positional=$((positional+1))
    [ "$positional" -eq 1 ] && continue                 # 1つ目の位置引数 = リモート
    # 裸の HEAD / @ はカレントブランチ参照なので明示ターゲットに数えない
    # （`git push origin HEAD` は main 上なら main へ push する＝カレント検査へ回す）
    case "$tok" in HEAD|@) continue ;; esac
    has_target=1
  done
  if [ "$has_target" -eq 0 ]; then
    current=$(git branch --show-current 2>/dev/null || echo "")
    if [ -z "$current" ]; then
      block "ブロック: カレントブランチを判定できません（detached HEAD / git リポジトリ外 / git 不在）。判定不能な push は安全側で止めます。push 先ブランチを明示するか、トピックブランチを作成してください。"
    fi
    if printf '%s' "$current" | grep -Eq "^(${PROTECTED_BRANCHES})$"; then
      block "ブロック: 現在 ${current} ブランチ上での push 先未指定の push は禁止です。トピックブランチを作成してから push してください。"
    fi
  fi
done

exit 0
