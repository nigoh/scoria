#!/usr/bin/env bash
# @file .claude/hooks/guard-protected.sh
# @brief PreToolUse(Edit|Write) hook: 保護ファイルへの直接編集を決定論的にブロックする。
# @description
#   ブロック時は「代わりに何をすべきか」を必ず案内する（exit 2 / stderr）。
#   対象を増やす場合はこのファイルの判定に追記し、CLAUDE.md 絶対原則・.claude/README.md の
#   hooks 表・scripts/test-hooks.sh / scripts/test-guard-protected.sh の再発防止ケースと同期する。
#   方針: 判定不能な状況（JSON パーサ不在・git 不在・origin/main 不在・パス相対化失敗）では
#         fail-closed（保護側＝ブロック）に倒す。fail-open は絶対原則の侵食になる。
#
#   保護対象:
#     1) シークレット類（.env 系・.envrc・鍵/証明書・資格情報ストア）… basename を小文字化して判定
#     2) ロックファイル（主要エコシステム）… パッケージマネージャで再生成させる
#     3) マージ済みの Accepted な ADR … 例外は (a) Status 行だけの supersede 更新
#        (b) まだ origin/main に無い ADR（導入 PR がマージ前）
#
#   迂回対策: `..`・`./`・重複スラッシュ・symlink を realpath で解決した実体パスでも判定し、
#   大小無視のファイルシステム（macOS/Windows）向けに小文字化して照合する。
#
# @stdin PreToolUse フックの JSON。`.tool_input.file_path` / `.old_string` / `.new_string` を
#   判定材料にする。jq → python3 → 純 bash 正規表現の順にフォールバック（パーサ不在時は
#   old/new を空にし、ADR の supersede 例外を成立させない＝ブロック側へ倒す）
# @stderr ブロック理由と代替手段（.env.example へ／パッケージマネージャで再生成／/adr で新 ADR）
# @exitcode 0 許可（保護対象外／file_path 抽出不能／ADR の supersede 例外・未マージ ADR に該当）
# @exitcode 2 ブロック（保護対象への編集）
# @see scripts/test-guard-protected.sh 契約テスト（迂回形の網羅）
set -u

# stdin の読み取りは外部コマンド（cat）に依存させない。PATH が壊れた環境でも
# 少なくともシークレット/ロックファイルの判定は動かす（fail-closed の担保）。
input=""
IFS= read -r -d '' input

if command -v jq >/dev/null 2>&1; then
  # -j（改行を付けない）+ 番兵 X で、末尾改行を含む old/new をそのまま取得する。
  # 文字列以外（null・数値・オブジェクト）は空扱いにして python3 経路と verdict を揃える。
  # @internal
  # @description stdin の JSON から `.tool_input.<key>` を文字列として取り出す（jq 経路）。
  # @arg $1 string 取り出すキー名（file_path|old_string|new_string）
  # @stdout 値（文字列以外・欠落は空文字）。末尾改行を付けない
  # @exitcode 0 常に成功（jq のエラーは握り潰して空文字にする）
  _jqx() { printf '%s' "$input" | jq -j --arg k "$1" '(.tool_input[$k]? // empty) | select(type=="string")' 2>/dev/null; }
  file_path=$(_jqx file_path)
  old_string=$(_jqx old_string; printf 'X'); old_string=${old_string%X}
  new_string=$(_jqx new_string; printf 'X'); new_string=${new_string%X}
elif command -v python3 >/dev/null 2>&1; then
  _PY='import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
t = d.get("tool_input") if isinstance(d, dict) else None
v = t.get(sys.argv[1]) if isinstance(t, dict) else None
sys.stdout.write(v if isinstance(v, str) else "")'
  # @internal
  # @description stdin の JSON から `.tool_input.<key>` を文字列として取り出す（python3 経路）。
  #   jq 経路と同じ verdict になるよう、文字列以外は空文字に落とす。
  # @arg $1 string 取り出すキー名（file_path|old_string|new_string）
  # @stdout 値（文字列以外・欠落は空文字）
  # @exitcode 0 常に成功（JSON 破損は握り潰して空文字にする）
  _pyx() { printf '%s' "$input" | python3 -c "$_PY" "$1" 2>/dev/null; }
  file_path=$(_pyx file_path)
  old_string=$(_pyx old_string; printf 'X'); old_string=${old_string%X}
  new_string=$(_pyx new_string; printf 'X'); new_string=${new_string%X}
else
  # jq も python3 も無い環境: 純 bash の粗い抽出で「保護対象を素通りさせない」側に倒す。
  # old/new は信頼できないので空のままにする（＝ADR の supersede 例外は成立せずブロックになる）。
  file_path=""; old_string=""; new_string=""
  _rest=$input
  while [[ $_rest =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"(.*) ]]; do
    file_path=${BASH_REMATCH[1]}
    _rest=${BASH_REMATCH[2]}
  done
fi

[ -z "${file_path:-}" ] && exit 0

# パス正規化: `..`・`./`・重複スラッシュ・symlink を解決した実体パスも判定対象にする
# （symlink や traversal で保護対象の実体に書き込む迂回を塞ぐ）。realpath が使えない環境では原文のまま。
real_path=$(realpath -m "$file_path" 2>/dev/null || realpath "$file_path" 2>/dev/null || printf '%s' "$file_path")
[ -z "${real_path:-}" ] && real_path="$file_path"

# @internal
# @description ブロック理由を stderr に出してフックを終了する（＝ツール実行を止める）。
# @arg $1 string ブロック理由と代替手段の案内（Claude に渡る）
# @stderr 引数の文字列
# @exitcode 2 常に（PreToolUse フックの「ブロック」規約）
block() { echo "$1" >&2; exit 2; }

# @internal
# @description 1) シークレット類・2) ロックファイル: ファイル名（basename）で判定する。
#    大小無視のファイルシステム（macOS/Windows）で `.ENV` `Gemfile.LOCK` が同一実体を指すため、
#    小文字化して照合する（case 変種での迂回を塞ぐ）。
#    元の basename と realpath 後の basename の両方に対して呼ぶ（symlink 迂回対策）。
# @arg $1 string 判定する basename（表示は原文のまま、照合は小文字化した値で行う）
# @exitcode 0 保護対象でない（.env.example のような明示的な許可を含む）
# @exitcode 2 保護対象だった（block でフックごと終了する）
check_name() {
  n=${1,,}
  case "$n" in
    # --- .env 系（direnv の .envrc、ハイフン/アンダースコア変種を含む） ---
    .env|.env.*|.env-*|.env_*)
      [ "$n" = ".env.example" ] && return 0
      block "ブロック: ${1} は編集禁止です。共有すべき設定は .env.example に追記してください。"
      ;;
    .envrc)
      block "ブロック: ${1}（direnv）は秘密を含みうるため編集禁止です。共有設定は .env.example へ。"
      ;;
    # --- 鍵・証明書・資格情報ストア ---
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|*.p8|*.der|*.crt|*.cer|*.ppk|*.gpg|*.asc|*.kdbx|\
    id_rsa|id_rsa.*|id_dsa|id_dsa.*|id_ecdsa|id_ecdsa.*|id_ed25519|id_ed25519.*|*_rsa|*_rsa.*|*_ed25519|*_ed25519.*|\
    service-account*.json|*-service-account.json|serviceaccount*.json)
      block "ブロック: 鍵・証明書ファイル (${1}) の作成・編集は禁止です。秘密は環境変数やシークレットマネージャで扱ってください。"
      ;;
    .netrc|_netrc|.pgpass|.git-credentials|.htpasswd)
      block "ブロック: 資格情報ファイル (${1}) の作成・編集は禁止です。秘密は環境変数やシークレットマネージャで扱ってください。"
      ;;
    # --- ロックファイル: 手編集禁止（パッケージマネージャで再生成する）。主要エコシステムを網羅 ---
    package-lock.json|npm-shrinkwrap.json|pnpm-lock.yaml|yarn.lock|bun.lockb|bun.lock|deno.lock|\
    cargo.lock|poetry.lock|uv.lock|pipfile.lock|pdm.lock|\
    gemfile.lock|berksfile.lock|composer.lock|go.sum|mix.lock|podfile.lock|package.resolved|cartfile.resolved|\
    gradle.lockfile|*gradle.lockfile|packages.lock.json|paket.lock|flake.lock|pubspec.lock|conan.lock|renv.lock|\
    stack.yaml.lock|cabal.project.freeze|.terraform.lock.hcl|terraform.lock.hcl)
      block "ブロック: ロックファイル (${1}) は手で編集せず、パッケージマネージャのコマンドで再生成してください。"
      ;;
  esac
}

base=$(basename -- "$file_path" 2>/dev/null || printf '%s' "$file_path")
rbase=$(basename -- "$real_path" 2>/dev/null || printf '%s' "$real_path")
check_name "$base"
[ "$rbase" != "$base" ] && check_name "$rbase"

# 3) Accepted な ADR: 編集禁止。例外は次の2つ:
#    (a) supersede 時の Status 行だけの更新（old_string が Status: Accepted 行、new_string が Superseded 行）
#    (b) まだ origin/main に無い ADR（導入 PR がマージ前の founding/新規 ADR は訂正可。マージ後は不可）
#    origin/main を参照できない環境（CI 等）ではフェイルクローズ（保護側）に倒す。
#    パスは正規化後（real_path）で判定し、`docs/adr/../adr/…` の traversal や大文字拡張子での迂回を塞ぐ。
lpath=${real_path,,}
case "$lpath" in
  *docs/adr/[0-9]*.md)
    if [ -f "$real_path" ] && grep -q "^- Status: Accepted" "$real_path" 2>/dev/null; then
      # (a) Status 行のみの supersede 更新を許可する。old_string / new_string の双方を
      #     「単一行の Status 行」に厳格一致させる（改行・見出し・コメント・リンク・日本語本文などを
      #     含む new_string を許すと、例外を踏み台に Accepted ADR の本文を改変できる抜け穴になる）。
      #     文字クラスに改行を含めないため、複数行の old/new はここで必ず不一致＝ブロックになる。
      _tail='[-A-Za-z0-9 ._,:/()]*'
      _re_old="^- Status: Accepted${_tail}\$"
      _re_new="^- Status: Superseded by (ADR-)?[0-9]{3,4}${_tail}\$"
      if [[ $old_string =~ $_re_old ]] && [[ $new_string =~ $_re_new ]]; then
        exit 0
      fi
      # (b) origin/main に未存在の ADR は訂正可（origin/main を参照できる場合のみ判定）
      proj="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname -- "$real_path")" rev-parse --show-toplevel 2>/dev/null)}"
      proj="${proj%/}"   # 末尾スラッシュを除去（付いていると相対化に失敗し fail-open するため）
      # proj と file_path がシンボリックリンク vs realpath で表現食い違うと相対化に失敗し、
      # rel が絶対パスのまま残って cat-file が必ず失敗→「未マージ」と誤判定して fail-open する
      # （--show-toplevel は realpath を返す一方 file_path は symlink 経路を持ちうる）。両者を
      # realpath で正規化し、さらに「相対化に成功したときだけ許可」して残余の失敗は fail-closed に倒す。
      rp_proj=$(realpath "$proj" 2>/dev/null || printf '%s' "$proj")
      rp_file=$(realpath "$real_path" 2>/dev/null || printf '%s' "$real_path")
      if [ -n "${rp_proj:-}" ] && git -C "$rp_proj" rev-parse --verify -q origin/main >/dev/null 2>&1; then
        rel="${rp_file#"$rp_proj"/}"
        # rel が絶対のまま（相対化失敗）なら許可しない＝fail-closed。成功時のみ未存在判定を行う。
        if [ "$rel" != "$rp_file" ] && ! git -C "$rp_proj" cat-file -e "origin/main:$rel" 2>/dev/null; then
          exit 0   # origin/main に未存在＝導入前の ADR → 訂正可
        fi
      fi
      echo "ブロック: マージ済みの Accepted ADR は編集禁止です。決定を覆す場合は /adr で新しい ADR を作成し、旧 ADR の Status 行のみを「Superseded by NNNN」に更新してください（その Edit だけ許可されます）。" >&2
      exit 2
    fi
    ;;
esac

exit 0
