#!/usr/bin/env bash
# @file scripts/test-guard-protected.sh
# @brief guard-protected.sh の敵対的テスト（表駆動）。
# @description
#   guard-protected.sh の敵対的テスト（表駆動）。
#   擬似ツールコール JSON を stdin に流し、ブロック(exit 2)/許可(exit 0) の契約を固定する。
#   観点: .env 系 / 鍵・証明書 / ロックファイル（各エコシステム）/ ADR ガバナンス /
#         パス形（相対・traversal・symlink・大小・空白・日本語・制御文字）/ フェイルセーフの向き。
#   方針: 判定不能なとき（git 不在・origin/main 不在・パーサ不在・相対化失敗）は
#         fail-closed（保護側=ブロック）に倒れることを検査する。fail-open は安全境界の侵食。
#   実リポジトリのファイルは一切書き換えない（JSON を流すだけ）。git 検証は隔離リポジトリで行う。
# @exitcode 0 全ケース合格
# @exitcode 1 いずれかのケースが不合格（git / python3 不在によるスキップも不合格として扱う）
# @stdout ケースごとの PASS 行とアサーション数
# @stderr 不合格ケースの FAIL 行
set -u

cd "$(dirname "$0")/.." || exit 1

P=.claude/hooks/guard-protected.sh
fail=0
total=0

# @description 期待値と実際値を突き合わせ、結果を記録する（全アサーションの共通出口）。
# @internal
# @arg $1 string ケースの説明
# @arg $2 int 期待する終了コード
# @arg $3 int 実際の終了コード
# @set total int アサーション数を1増やす
# @set fail int 不一致なら 1
chk() { # $1=説明 $2=期待exit $3=実際exit
  total=$((total + 1))
  if [ "$3" = "$2" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (want=$2 got=$3)" >&2
    fail=1
  fi
}

# @description 擬似ツールコール JSON を guard-protected に流し、終了コードを出力する。
# @internal
# @arg $1 string stdin に流すフック JSON
# @stdout guard-protected.sh の終了コード（2=ブロック / 0=許可）
run() { # $1=JSON → exit code
  printf '%s' "$1" | bash "$P" >/dev/null 2>&1
  echo $?
}

# @description パスを JSON 文字列値として埋め込める形にエスケープする
#   （\ と " のみ。生 UTF-8 はそのまま通し、日本語パスを検査できるようにする）。
# @internal
# @arg $1 string エスケープ対象の文字列
# @stdout エスケープ済みの文字列
jesc() { # JSON 文字列用に \ と " をエスケープ（生 UTF-8 はそのまま通す）
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

# @description file_path だけを持つ擬似ツールコールを流し、ブロック/許可の判定を検証する。
# @internal
# @arg $1 string ケースの説明
# @arg $2 path 編集対象として渡す file_path
# @arg $3 int 期待する終了コード（2=ブロック / 0=許可）
# @set fail int 不一致なら 1
fp() { # $1=説明 $2=file_path $3=期待exit
  chk "$1" "$3" "$(run "{\"tool_input\":{\"file_path\":\"$(jesc "$2")\"}}")"
}

# @description 「期待exit|パス|説明」の表を標準入力から読み、各行を fp で検証する（表駆動）。
#   空行と # で始まる行は読み飛ばす。
# @internal
# @stdin 「期待exit|パス|説明」形式の行の並び
# @set fail int いずれかの行が不一致なら 1
table() { # 標準入力から「期待exit|パス|説明」の表を読んで fp する
  local want path desc
  while IFS='|' read -r want path desc; do
    case "${want:-}" in '' | '#'*) continue ;; esac
    fp "$desc" "$path" "$want"
  done
}

# ============================================================
# 1) .env 系（絶対原則: .env は直接編集しない）
# ============================================================
table <<'TBL'
2|/repo/.env|.env をブロック
2|/repo/.env.local|.env.local をブロック
2|/repo/.env.production|.env.production をブロック
2|/repo/.env.test|.env.test をブロック
2|/repo/.env.development.local|.env.development.local をブロック
2|/repo/.env.production.local|.env.production.local をブロック
2|/repo/.env.staging|.env.staging をブロック
2|/repo/.env.vault|.env.vault をブロック
2|/repo/.env.keys|.env.keys をブロック
2|/repo/.env.local.bak|.env.local.bak（退避名）をブロック
2|/repo/.envrc|.envrc(direnv) をブロック
2|apps/web/.env|サブディレクトリ配下の .env をブロック
2|/a/b/c/d/e/.env.local|深いサブディレクトリの .env.local をブロック
2|./.env|./ 相対の .env をブロック
2|../.env|../ 相対の .env をブロック
2|.env|裸の .env をブロック
2|docs/adr/../../.env|traversal 経由の .env をブロック
2|/repo/.ENV|大文字 .ENV をブロック（大小無視FS対策）
2|/repo/.Env.Local|大小混在 .Env.Local をブロック
2|/repo/.ENVRC|大文字 .ENVRC をブロック
2|/repo/.EnvRc|大小混在 .EnvRc をブロック
2|/repo/.env-local|.env-local（ハイフン変種）をブロック
2|/repo/.env_local|.env_local（アンダースコア変種）をブロック
2|/repo/.env.|末尾ドットの .env. をブロック
0|/repo/.env.example|.env.example を許可
0|apps/web/.env.example|サブディレクトリの .env.example を許可
0|/repo/.ENV.EXAMPLE|大文字 .ENV.EXAMPLE を許可（同一FSエントリ扱い）
2|/repo/.env.sample|.env.sample はブロック（現契約: example のみ許可）
2|/repo/.env.template|.env.template はブロック（現契約: example のみ許可）
0|/repo/environment.ts|environment.ts を許可（誤検知しない）
0|/repo/env.js|env.js を許可
0|/repo/src/env/index.ts|env ディレクトリ配下の通常ファイルを許可
0|/repo/.environment|.environment を許可
0|/repo/dotenv.md|dotenv.md を許可
0|/repo/env.example|env.example（ドット無し）を許可
0|/repo/README.env.md|README.env.md を許可
TBL

# ============================================================
# 2) 鍵・証明書（絶対原則: 鍵ファイルは直接編集しない）
# ============================================================
table <<'TBL'
2|/repo/server.pem|*.pem をブロック
2|/repo/certs/ca-cert.pem|サブディレクトリの *.pem をブロック
2|/repo/private.key|*.key をブロック
2|/repo/tls/server.KEY|大文字 *.KEY をブロック
2|/repo/SERVER.PEM|大文字 *.PEM をブロック
2|/home/u/.ssh/id_rsa|id_rsa をブロック
2|/home/u/.ssh/id_rsa.pub|id_rsa.pub をブロック（対の公開鍵も手編集不可）
2|/home/u/.ssh/id_ed25519|id_ed25519 をブロック
2|/home/u/.ssh/id_ed25519.pub|id_ed25519.pub をブロック
2|/home/u/.ssh/id_ecdsa|id_ecdsa をブロック
2|/home/u/.ssh/id_dsa|id_dsa をブロック
2|/home/u/.ssh/ID_RSA|大文字 ID_RSA をブロック
2|/repo/deploy_rsa|deploy_rsa（_rsa 接尾）をブロック
2|/repo/cert.p12|*.p12 をブロック
2|/repo/cert.pfx|*.pfx をブロック
2|/repo/release.jks|*.jks をブロック
2|/repo/app.keystore|*.keystore をブロック
2|/repo/AuthKey_ABC123.p8|*.p8（Apple 認証鍵）をブロック
2|/repo/cert.der|*.der をブロック
2|/repo/cert.crt|*.crt をブロック
2|/repo/cert.cer|*.cer をブロック
2|/repo/putty.ppk|*.ppk をブロック
2|/repo/secring.gpg|*.gpg をブロック
2|/repo/vault.kdbx|*.kdbx をブロック
2|/repo/service-account.json|service-account.json をブロック
2|/repo/service-account-prod.json|service-account-prod.json をブロック
2|/repo/gcp-service-account.json|*-service-account.json をブロック
2|/repo/SERVICE-ACCOUNT.JSON|大文字 SERVICE-ACCOUNT.JSON をブロック
2|/home/u/.netrc|.netrc（資格情報）をブロック
2|/home/u/_netrc|_netrc をブロック
2|/home/u/.pgpass|.pgpass をブロック
2|/home/u/.git-credentials|.git-credentials をブロック
2|/repo/.htpasswd|.htpasswd をブロック
0|/repo/src/key.ts|key.ts を許可（誤検知しない）
0|/repo/src/keys.json|keys.json を許可
0|/repo/src/monkey.js|monkey.js を許可
0|/repo/docs/apikey.md|apikey.md を許可
0|/repo/docs/keystore.md|keystore.md を許可
0|/repo/docs/certificates.md|certificates.md を許可
0|/repo/docs/service-account.md|service-account.md を許可
0|/repo/accounts.json|accounts.json を許可
0|/repo/pem.txt|pem.txt を許可
0|/repo/src/keychain.ts|keychain.ts を許可
TBL

# ============================================================
# 3) ロックファイル（絶対原則: パッケージマネージャで再生成する）
# ============================================================
table <<'TBL'
2|/repo/package-lock.json|package-lock.json をブロック
2|/repo/npm-shrinkwrap.json|npm-shrinkwrap.json をブロック
2|/repo/pnpm-lock.yaml|pnpm-lock.yaml をブロック
2|/repo/yarn.lock|yarn.lock をブロック
2|/repo/bun.lockb|bun.lockb をブロック
2|/repo/bun.lock|bun.lock（テキスト版）をブロック
2|/repo/deno.lock|deno.lock をブロック
2|/repo/Cargo.lock|Cargo.lock をブロック
2|/repo/poetry.lock|poetry.lock をブロック
2|/repo/uv.lock|uv.lock をブロック
2|/repo/Pipfile.lock|Pipfile.lock をブロック
2|/repo/pdm.lock|pdm.lock をブロック
2|/repo/Gemfile.lock|Gemfile.lock をブロック
2|/repo/Berksfile.lock|Berksfile.lock をブロック
2|/repo/composer.lock|composer.lock をブロック
2|/repo/go.sum|go.sum をブロック
2|/repo/mix.lock|mix.lock をブロック
2|/repo/Podfile.lock|Podfile.lock をブロック
2|/repo/Package.resolved|Package.resolved をブロック
2|/repo/Cartfile.resolved|Cartfile.resolved をブロック
2|/repo/gradle.lockfile|gradle.lockfile をブロック
2|/repo/buildscript-gradle.lockfile|buildscript-gradle.lockfile をブロック
2|/repo/packages.lock.json|packages.lock.json(NuGet) をブロック
2|/repo/paket.lock|paket.lock をブロック
2|/repo/flake.lock|flake.lock(Nix) をブロック
2|/repo/pubspec.lock|pubspec.lock(Dart) をブロック
2|/repo/conan.lock|conan.lock をブロック
2|/repo/renv.lock|renv.lock(R) をブロック
2|/repo/stack.yaml.lock|stack.yaml.lock(Haskell) をブロック
2|/repo/cabal.project.freeze|cabal.project.freeze をブロック
2|/repo/.terraform.lock.hcl|.terraform.lock.hcl をブロック
2|/repo/terraform.lock.hcl|terraform.lock.hcl をブロック
2|/repo/apps/web/package-lock.json|サブディレクトリの package-lock.json をブロック
2|/repo/Gemfile.LOCK|大文字 Gemfile.LOCK をブロック（大小無視FS対策）
2|/repo/CARGO.LOCK|大文字 CARGO.LOCK をブロック
2|/repo/PACKAGE-LOCK.JSON|大文字 PACKAGE-LOCK.JSON をブロック
2|/repo/Yarn.Lock|大小混在 Yarn.Lock をブロック
2|./package-lock.json|./ 相対の package-lock.json をブロック
2|docs/../go.sum|traversal 経由の go.sum をブロック
0|/repo/package.json|package.json を許可
0|/repo/Cargo.toml|Cargo.toml を許可
0|/repo/Gemfile|Gemfile を許可
0|/repo/go.mod|go.mod を許可
0|/repo/pnpm-workspace.yaml|pnpm-workspace.yaml を許可
0|/repo/Pipfile|Pipfile を許可
0|/repo/composer.json|composer.json を許可
0|/repo/pubspec.yaml|pubspec.yaml を許可
0|/repo/docs/lockfiles.md|lockfiles.md を許可
0|/repo/src/lock.ts|lock.ts を許可
0|/repo/src/mylock.yaml|mylock.yaml を許可
0|/repo/yarn.lockfile|yarn.lockfile（非標準名）を許可
0|/repo/stack.yaml|stack.yaml を許可
0|/repo/terraform.tfstate|terraform.tfstate を許可
TBL

# ============================================================
# 4) パス形（空白・日本語・制御文字・引用符・末尾スラッシュ・symlink）
# ============================================================
fp "空白を含むディレクトリ配下の .env をブロック" "/my dir/app/.env" 2
fp "日本語パス配下の .env をブロック" "/リポジトリ/設定/.env" 2
fp "日本語ファイル名の通常ファイルを許可" "/リポジトリ/設計メモ.md" 0
fp "引用符を含むパスの .env をブロック" '/re"po/.env' 2
fp "バックスラッシュを含むパスの .env をブロック" '/re\po/.env' 2
fp "空白を含む日本語パスのロックファイルをブロック" "/私の repo/pnpm-lock.yaml" 2
fp "末尾スラッシュ付き .env をブロック" "/repo/.env/" 2
fp "重複スラッシュの .env をブロック" "/repo//.env" 2
chk "制御文字(タブ)を含むパスの .env をブロック" 2 \
  "$(run '{"tool_input":{"file_path":"/repo/a\tb/.env"}}')"
chk "改行を含むパスでも末尾の .env をブロック" 2 \
  "$(run '{"tool_input":{"file_path":"/repo/x\n/.env"}}')"
chk "エスケープされた引用符入りパスの .env をブロック" 2 \
  "$(run '{"tool_input":{"file_path":"/re\"po/.env"}}')"

# symlink 経由（ファイル・ディレクトリ両方）: 実体が保護対象なら解決してブロックする
sl=$(mktemp -d)
mkdir -p "$sl/real"
: > "$sl/real/.env"
: > "$sl/real/package-lock.json"
ln -s "$sl/real/.env" "$sl/env-link"           # ファイル symlink → .env
ln -s "$sl/real/package-lock.json" "$sl/ll"    # ファイル symlink → ロックファイル
ln -s "$sl/real" "$sl/dirlink"                 # ディレクトリ symlink
fp "ファイル symlink 経由の .env をブロック（実体解決）" "$sl/env-link" 2
fp "ファイル symlink 経由のロックファイルをブロック" "$sl/ll" 2
fp "ディレクトリ symlink 経由の .env をブロック" "$sl/dirlink/.env" 2
fp "ディレクトリ symlink 経由の通常ファイルを許可" "$sl/dirlink/README.md" 0
rm -rf "$sl"

# ============================================================
# 5) フェイルセーフ（壊れた入力・パーサ欠落・二重バックエンド等価性）
# ============================================================
chk "空 JSON は許可（file_path 不明）" 0 "$(run '{}')"
chk "空入力は許可" 0 "$(run '')"
chk "file_path 欠落は許可" 0 "$(run '{"tool_input":{"old_string":"a"}}')"
chk "tool_input 欠落は許可" 0 "$(run '{"foo":1}')"
chk "壊れた JSON は許可（判定不能・現契約）" 0 "$(run '{"tool_input":{"file_path":')"
chk "file_path が空文字は許可" 0 "$(run '{"tool_input":{"file_path":""}}')"
chk "file_path が null は許可" 0 "$(run '{"tool_input":{"file_path":null}}')"
chk "file_path が数値は許可" 0 "$(run '{"tool_input":{"file_path":123}}')"
chk "file_path がオブジェクトは許可" 0 "$(run '{"tool_input":{"file_path":{"a":1}}}')"
chk "tool_input が文字列は許可" 0 "$(run '{"tool_input":"x"}')"
chk "JSON 配列ルートは許可" 0 "$(run '[1,2,3]')"
chk "重複キーは後勝ちで .env をブロック" 2 \
  "$(run '{"tool_input":{"file_path":"README.md","file_path":"/repo/.env"}}')"
chk "本文に .env 文字列があるだけの通常編集は許可" 0 \
  "$(run '{"tool_input":{"file_path":"/repo/docs/setup.md","new_string":"cp .env.example .env"}}')"

# パーサ backend を切り替えた等価性検査（jq 経路 ⇄ python3 経路）と、
# 双方欠落時のフェイルセーフの向き。PATH を絞ったスタブ bin で再現する。
# @description PATH サンドボックス用の bin ディレクトリを作り、指定コマンドだけを symlink する。
#   パーサ backend を切り替えた等価性検査と、双方欠落時のフェイルセーフの向きの再現に使う。
# @internal
# @arg $@ string symlink するコマンド名
# @stdout 作成した bin ディレクトリのパス
mkbin() { # $@=必要コマンド → 生成した bin ディレクトリを返す
  local d p b
  d=$(mktemp -d)
  for b in "$@"; do
    p=$(command -v "$b" 2>/dev/null) && ln -s "$p" "$d/$b"
  done
  printf '%s' "$d"
}
BASE_TOOLS="cat basename grep git realpath sed tr dirname"
# shellcheck disable=SC2086
NOJQ=$(mkbin $BASE_TOOLS python3)
# shellcheck disable=SC2086
NOPARSER=$(mkbin $BASE_TOOLS)
HOOK_ABS="$PWD/$P"

# @description PATH を絞った環境で guard-protected を実行し、終了コードを出力する。
# @internal
# @arg $1 string 実行時の PATH（利用可能なパーサを限定する）
# @arg $2 string stdin に流すフック JSON
# @stdout guard-protected.sh の終了コード
runp() { # $1=PATH $2=JSON → exit code
  printf '%s' "$2" | PATH="$1" "$BASH" "$HOOK_ABS" >/dev/null 2>&1
  echo $?
}

if [ -x "$NOJQ/python3" ]; then
  while IFS='|' read -r want path desc; do
    case "${want:-}" in '' | '#'*) continue ;; esac
    json="{\"tool_input\":{\"file_path\":\"$(jesc "$path")\"}}"
    jq_rc=$(run "$json")
    py_rc=$(runp "$NOJQ" "$json")
    chk "python3 経路: $desc" "$want" "$py_rc"
    chk "jq⇄python3 等価: $desc" "$jq_rc" "$py_rc"
  done <<'TBL'
2|/repo/.env|.env をブロック
2|/repo/.env.local|.env.local をブロック
0|/repo/.env.example|.env.example を許可
2|/repo/.envrc|.envrc をブロック
2|/repo/server.pem|*.pem をブロック
2|/home/u/.ssh/id_rsa|id_rsa をブロック
2|/repo/cert.p12|*.p12 をブロック
2|/repo/package-lock.json|package-lock.json をブロック
2|/repo/Gemfile.lock|Gemfile.lock をブロック
2|/repo/flake.lock|flake.lock をブロック
2|/repo/.ENV|大文字 .ENV をブロック
0|/repo/README.md|通常ファイルを許可
0|/repo/package.json|package.json を許可
0|/リポジトリ/設定/README.md|日本語パスの通常ファイルを許可
2|/リポジトリ/設定/.env|日本語パスの .env をブロック
TBL
  for j in '{}' '{"tool_input":{"file_path":null}}' '{"tool_input":{"file_path":123}}' \
    '{"tool_input":"x"}' '{"tool_input":{"file_path":""}}' '[1,2,3]'; do
    chk "jq⇄python3 等価（非文字列/欠落入力: $j）" "$(run "$j")" "$(runp "$NOJQ" "$j")"
  done
  chk "python3 経路: 空 JSON は許可" 0 "$(runp "$NOJQ" '{}')"
else
  echo "FAIL: python3 スタブを用意できず backend 等価性を検証できない" >&2
  fail=1
fi

# jq も python3 も無い環境: 保護対象は素通りさせない（fail-closed）
chk "パーサ不在でも .env をブロック（fail-closed）" 2 \
  "$(runp "$NOPARSER" '{"tool_input":{"file_path":"/repo/.env"}}')"
chk "パーサ不在でも .envrc をブロック" 2 \
  "$(runp "$NOPARSER" '{"tool_input":{"file_path":"/repo/.envrc"}}')"
chk "パーサ不在でも鍵ファイルをブロック" 2 \
  "$(runp "$NOPARSER" '{"tool_input":{"file_path":"/repo/server.pem"}}')"
chk "パーサ不在でもロックファイルをブロック" 2 \
  "$(runp "$NOPARSER" '{"tool_input":{"file_path":"/repo/package-lock.json"}}')"
chk "パーサ不在でも通常ファイルは許可" 0 \
  "$(runp "$NOPARSER" '{"tool_input":{"file_path":"/repo/README.md"}}')"
chk "パーサ不在で空 JSON は許可" 0 "$(runp "$NOPARSER" '{}')"
rm -rf "$NOJQ" "$NOPARSER"

# ============================================================
# 6) ADR ガバナンス（隔離 git リポジトリで決定論的に検証）
# ============================================================
# @description ADR 編集を表す擬似ツールコール JSON（file_path / old_string / new_string）を組み立てる。
# @internal
# @arg $1 path 編集対象の ADR パス
# @arg $2 string old_string（JSON エスケープ済みで渡す）
# @arg $3 string new_string（JSON エスケープ済みで渡す）
# @stdout 組み立てたフック JSON
adr_json() { # $1=file_path $2=old(JSON済) $3=new(JSON済)
  printf '{"tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}' \
    "$(jesc "$1")" "$2" "$3"
}

# @description ADR ガバナンスの1ケースを検証する（マージ済み Accepted ADR の保護と supersede 例外）。
# @internal
# @arg $1 string ケースの説明
# @arg $2 path 編集対象の ADR パス
# @arg $3 string old_string
# @arg $4 string new_string
# @arg $5 path CLAUDE_PROJECT_DIR に渡す値（"-" なら未設定で実行する）
# @arg $6 int 期待する終了コード（2=ブロック / 0=許可）
# @set fail int 不一致なら 1
adr() { # $1=説明 $2=file_path $3=old $4=new $5=proj（"-"=未設定）$6=期待exit
  local rc
  if [ "$5" = "-" ]; then
    rc=$(printf '%s' "$(adr_json "$2" "$3" "$4")" | env -u CLAUDE_PROJECT_DIR bash "$P" >/dev/null 2>&1; echo $?)
  else
    rc=$(printf '%s' "$(adr_json "$2" "$3" "$4")" | CLAUDE_PROJECT_DIR="$5" bash "$P" >/dev/null 2>&1; echo $?)
  fi
  chk "$1" "$6" "$rc"
}

if command -v git >/dev/null 2>&1; then
  gw=$(mktemp -d)
  git init -q --bare "$gw/o.git"
  git clone -q "$gw/o.git" "$gw/c" >/dev/null 2>&1
  (
    cd "$gw/c" || exit 1
    git config user.email t@example.com
    git config user.name tester
    mkdir -p docs/adr
    printf '# 0001: merged\n- Status: Accepted\n\n## Context\nx\n' > docs/adr/0001-merged.md
    printf '# 0003: proposed\n- Status: Proposed\n\n## Context\nx\n' > docs/adr/0003-proposed.md
    printf '# 0006: upper\n- Status: Accepted\n\n## Context\nx\n' > docs/adr/0006-upper.MD
    printf '# template\n- Status: Proposed\n' > docs/adr/template.md
    printf '# index\n' > docs/adr/README.md
    git add -A
    git commit -qm init
    git push -q origin HEAD:main
    git fetch -q origin
  ) >/dev/null 2>&1
  # main 未マージの Accepted ADR（commit も push もしない）
  printf '# 0002: unmerged\n- Status: Accepted\n\n## Context\ny\n' > "$gw/c/docs/adr/0002-unmerged.md"
  C="$gw/c"
  M="$C/docs/adr/0001-merged.md"
  U="$C/docs/adr/0002-unmerged.md"

  # --- 6a) 基本契約 ---
  adr "マージ済み Accepted ADR の本文編集をブロック" "$M" '## Context' '## X' "$C" 2
  adr "マージ済み Accepted ADR の Write(old/new 無し)をブロック" "$M" '' '' "$C" 2
  adr "未マージ Accepted ADR の本文編集を許可（レビュー中の推敲）" "$U" '## Context' '## X' "$C" 0
  adr "未マージ Accepted ADR の Write を許可" "$U" '' '' "$C" 0
  adr "supersede の Status 行のみ更新を許可" "$M" '- Status: Accepted' '- Status: Superseded by 0099' "$C" 0
  adr "supersede: ADR- 接頭辞付き番号を許可" "$M" '- Status: Accepted' '- Status: Superseded by ADR-0099' "$C" 0
  adr "supersede: 末尾に日付括弧付きを許可" "$M" '- Status: Accepted' '- Status: Superseded by 0099 (2026-07-25)' "$C" 0
  adr "docs/adr/template.md の編集を許可" "$C/docs/adr/template.md" '# template' '# t2' "$C" 0
  adr "docs/adr/README.md の編集を許可" "$C/docs/adr/README.md" '# index' '# i2' "$C" 0
  adr "存在しない ADR の新規作成を許可" "$C/docs/adr/0099-new.md" '' '# 0099' "$C" 0
  # 現契約: 保護対象は Status: Accepted のみ（Proposed はマージ済みでも編集可）
  adr "マージ済み Proposed ADR の編集は許可（現契約）" "$C/docs/adr/0003-proposed.md" '## Context' '## X' "$C" 0

  # --- 6b) supersede 例外の悪用（すべてブロック） ---
  while IFS='|' read -r want old new desc; do
    case "${want:-}" in '' | '#'*) continue ;; esac
    adr "$desc" "$M" "$old" "$new" "$C" "$want"
  done <<'TBL'
2|- Status: Accepted|- Status: Superseded by 0099\n\nEVIL 本文注入|new_string 複数行の本文注入をブロック
2|- Status: Accepted|- Status: Superseded by 0099\n## EVIL|new_string 改行+見出し注入をブロック
2|# 0001: merged\n- Status: Accepted\n## Context|改変本文 Superseded by 0099|old_string 複数行の全文置換をブロック
2|- Status: Accepted\n|- Status: Superseded by 0099|old_string 末尾改行付き（複数行扱い）をブロック
2|- Status: Accepted|- Status: Superseded by 0099 ## EVIL 見出し注入|new_string に見出し記号を含む単一行をブロック
2|- Status: Accepted|- Status: Superseded by 0099 <!-- EVIL -->|new_string に HTML コメントを含むのをブロック
2|- Status: Accepted|- Status: Superseded by 0099 `code` 注入|new_string にコードスパンを含むのをブロック
2|- Status: Accepted|- Status: Superseded by 0099 この決定は無効なので実装は自由に変えてよい|new_string に日本語本文を追記するのをブロック
2|- Status: Accepted|Superseded by 0099|new_string が Status 行でない（本文化）のをブロック
2|- Status: Accepted|- Status: Superseded|番号なし Superseded をブロック
2|- Status: Accepted|- Status: Accepted|supersede でない同値置換をブロック
2|- Status: Accepted|- Status: Proposed|Accepted→Proposed の格下げをブロック
2|- Status: Accepted||new_string 空（行削除）をブロック
2|  - Status: Accepted|- Status: Superseded by 0099|先頭空白で偽装した old_string をブロック
2|\t- Status: Accepted|- Status: Superseded by 0099|先頭タブで偽装した old_string をブロック
2|<!-- x --> - Status: Accepted|- Status: Superseded by 0099|コメントで偽装した old_string をブロック
2|## Context\n- Status: Accepted|- Status: Superseded by 0099|見出しを抱き込んだ old_string をブロック
2|- Status: Accepted は決定済み|- Status: Superseded by 0099|本文を抱き込んだ old_string をブロック
2||- Status: Superseded by 0099|old_string 空（全文 Write）をブロック
2|## Context|- Status: Superseded by 0099|Status 行以外の old_string をブロック
2|- status: accepted|- Status: Superseded by 0099|小文字偽装の old_string をブロック
2|- Status: Accepted|- Status: Superseded by 0099 [link](http://evil)|new_string にリンク注入をブロック
2|- Status: Accepted|- Status: Superseded by 0099; rm -rf /|new_string にシェル片を含むのをブロック
TBL

  # --- 6c) CLAUDE_PROJECT_DIR / パス正規化 ---
  adr "CLAUDE_PROJECT_DIR 末尾スラッシュでもマージ済みをブロック" "$M" '## Context' '## X' "$C/" 2
  adr "CLAUDE_PROJECT_DIR 末尾スラッシュでも未マージは許可" "$U" '## Context' '## X' "$C/" 0
  adr "CLAUDE_PROJECT_DIR 未設定でもマージ済みをブロック（git 探索）" "$M" '## Context' '## X' "-" 2
  adr "CLAUDE_PROJECT_DIR 未設定でも未マージは許可" "$U" '## Context' '## X' "-" 0
  adr "traversal 経由（docs/adr/../adr/）のマージ済み編集をブロック" \
    "$C/docs/adr/../adr/0001-merged.md" '## Context' '## X' "$C" 2
  adr "traversal 経由（./ 混じり）のマージ済み編集をブロック" \
    "$C/./docs/./adr/0001-merged.md" '## Context' '## X' "$C" 2
  adr "重複スラッシュ経由のマージ済み編集をブロック" \
    "$C/docs//adr//0001-merged.md" '## Context' '## X' "$C" 2
  adr "大文字拡張子 .MD のマージ済み ADR をブロック" \
    "$C/docs/adr/0006-upper.MD" '## Context' '## X' "$C" 2
  adr "無関係な CLAUDE_PROJECT_DIR ではマージ済みをブロック（相対化失敗=fail-closed）" \
    "$M" '## Context' '## X' "$gw" 2
  adr "無関係な CLAUDE_PROJECT_DIR では未マージもブロック（fail-closed 側に倒れる）" \
    "$U" '## Context' '## X' "$gw" 2

  # symlink（proj と file_path の表現が食い違っても fail-open しない）
  ln -s "$gw/c" "$gw/link" 2>/dev/null
  if [ -L "$gw/link" ]; then
    adr "symlink 経路のマージ済み ADR をブロック（fail-open 回帰）" \
      "$gw/link/docs/adr/0001-merged.md" '## Context' '## X' "$C" 2
    adr "symlink proj でも未マージ ADR は許可（過剰ブロックしない）" \
      "$U" '## Context' '## X' "$gw/link" 0
    adr "symlink proj + symlink file でもマージ済みをブロック" \
      "$gw/link/docs/adr/0001-merged.md" '## Context' '## X' "$gw/link" 2
    adr "symlink 経路 + 末尾スラッシュ proj でもマージ済みをブロック" \
      "$gw/link/docs/adr/0001-merged.md" '## Context' '## X' "$gw/link/" 2
    adr "symlink 経路のマージ済み ADR は supersede のみ許可" \
      "$gw/link/docs/adr/0001-merged.md" '- Status: Accepted' '- Status: Superseded by 0099' "$C" 0
  fi

  # --- 6d) git が判定不能な状況（すべて fail-closed = ブロック） ---
  # origin/main が無いリポジトリ
  mkdir -p "$gw/norem/docs/adr"
  ( cd "$gw/norem" && git init -q && git config user.email t@e.x && git config user.name t ) >/dev/null 2>&1
  printf '# 0001\n- Status: Accepted\n\n## Context\nz\n' > "$gw/norem/docs/adr/0001-x.md"
  adr "origin/main が無い環境では Accepted ADR をブロック（fail-closed）" \
    "$gw/norem/docs/adr/0001-x.md" '## Context' '## X' "$gw/norem" 2
  adr "origin/main 不在でも supersede の Status 行更新は許可" \
    "$gw/norem/docs/adr/0001-x.md" '- Status: Accepted' '- Status: Superseded by 0099' "$gw/norem" 0

  # git 管理外のディレクトリ
  mkdir -p "$gw/nogit/docs/adr"
  printf '# 0001\n- Status: Accepted\n\n## Context\nz\n' > "$gw/nogit/docs/adr/0001-x.md"
  adr "git 管理外の Accepted ADR をブロック（fail-closed）" \
    "$gw/nogit/docs/adr/0001-x.md" '## Context' '## X' "$gw/nogit" 2
  adr "CLAUDE_PROJECT_DIR 未設定 + git 管理外でもブロック" \
    "$gw/nogit/docs/adr/0001-x.md" '## Context' '## X' "-" 2
  adr "CLAUDE_PROJECT_DIR が存在しないパスでもブロック" \
    "$M" '## Context' '## X' "$gw/does-not-exist" 2

  # detached HEAD（origin/main は参照できる）
  git clone -q -b main "$gw/o.git" "$gw/d" >/dev/null 2>&1
  ( cd "$gw/d" && git checkout -q --detach HEAD ) >/dev/null 2>&1
  printf '# 0002: unmerged\n- Status: Accepted\n\n## Context\ny\n' > "$gw/d/docs/adr/0002-unmerged.md"
  adr "detached HEAD でもマージ済み ADR をブロック" \
    "$gw/d/docs/adr/0001-merged.md" '## Context' '## X' "$gw/d" 2
  adr "detached HEAD でも未マージ ADR は許可" \
    "$gw/d/docs/adr/0002-unmerged.md" '## Context' '## X' "$gw/d" 0

  # git コマンドが無い環境（PATH から git を外す）: マージ判定不能 → ブロック
  nogit_bin=$(mkbin cat basename grep realpath sed tr dirname jq python3)
  rc=$(printf '%s' "$(adr_json "$M" '## Context' '## X')" \
    | PATH="$nogit_bin" CLAUDE_PROJECT_DIR="$C" "$BASH" "$HOOK_ABS" >/dev/null 2>&1; echo $?)
  chk "git 不在では Accepted ADR をブロック（fail-closed）" 2 "$rc"
  rc=$(printf '%s' "$(adr_json "$U" '## Context' '## X')" \
    | PATH="$nogit_bin" CLAUDE_PROJECT_DIR="$C" "$BASH" "$HOOK_ABS" >/dev/null 2>&1; echo $?)
  chk "git 不在では未マージ ADR もブロック（安全側）" 2 "$rc"
  rc=$(printf '%s' "$(adr_json "$M" '- Status: Accepted' '- Status: Superseded by 0099')" \
    | PATH="$nogit_bin" CLAUDE_PROJECT_DIR="$C" "$BASH" "$HOOK_ABS" >/dev/null 2>&1; echo $?)
  chk "git 不在でも supersede の Status 行更新は許可" 0 "$rc"
  rm -rf "$nogit_bin"

  # --- 6e) ADR ディレクトリ内の保護対象ファイル（他の判定を素通りしない） ---
  adr "docs/adr 配下の .env もブロック" "$C/docs/adr/.env" '' '' "$C" 2
  adr "docs/adr/../../.env の traversal をブロック" "$C/docs/adr/../../.env" '' '' "$C" 2

  rm -rf "$gw"
else
  echo "FAIL: git が無く ADR ガバナンスを検証できない（skip は検証済みと数えない）" >&2
  fail=1
fi

# ============================================================
# 7) 実リポジトリの ADR（読み取りのみ。ファイルは書き換えない）
# ============================================================
# 期待値は「その ADR が origin/main に在るか」で決まる。それが guard の契約そのものだから
# （マージ済み＝編集禁止 / 未マージ＝導入前なので訂正可）。期待値をブロック固定にすると、
# ADR がまだ main に無いリポジトリ（土台を移植した直後など）で偽赤になる。
# マージ済み側の網羅は 6) の隔離 git リポジトリが決定論的に担保しており、ここは
# 「実リポジトリの実状態に対して hook が契約どおり動くか」の確認に徹する。
# guard は3状態を持つ。許可になるのは真ん中だけで、origin/main を参照できない環境
# （CI の浅い checkout など）は「未マージ」ではなく fail-closed でブロックに倒れる。
adr_rel="docs/adr/0001-steering-placement-policy.md"
if ! git rev-parse --verify -q origin/main >/dev/null 2>&1; then
  adr_want=2; adr_state="origin/main を参照できない→fail-closed でブロック"
elif git cat-file -e "origin/main:$adr_rel" 2>/dev/null; then
  adr_want=2; adr_state="main マージ済み→ブロック"
else
  adr_want=0; adr_state="main 未マージ→訂正可"
fi
chk "実リポジトリの Accepted ADR 本文編集（$adr_state）" "$adr_want" \
  "$(run "{\"tool_input\":{\"file_path\":\"$PWD/$adr_rel\",\"old_string\":\"## Context\",\"new_string\":\"## X\"}}")"
chk "実リポジトリの Accepted ADR: supersede の Status 行更新は許可" 0 \
  "$(run "{\"tool_input\":{\"file_path\":\"$PWD/$adr_rel\",\"old_string\":\"- Status: Accepted\",\"new_string\":\"- Status: Superseded by 0099\"}}")"
chk "実リポジトリの相対パス ADR 編集も同じ判定（$adr_state）" "$adr_want" \
  "$(run "{\"tool_input\":{\"file_path\":\"$adr_rel\",\"old_string\":\"## Context\",\"new_string\":\"## X\"}}")"
chk "実リポジトリの ADR template を許可" 0 \
  "$(run "{\"tool_input\":{\"file_path\":\"$PWD/docs/adr/template.md\"}}")"
chk "実リポジトリの通常ファイル編集を許可" 0 \
  "$(run "{\"tool_input\":{\"file_path\":\"$PWD/README.md\"}}")"
chk "存在しない ADR 番号のファイルは許可" 0 \
  "$(run "{\"tool_input\":{\"file_path\":\"$PWD/docs/adr/0999-not-exist.md\"}}")"

echo ""
echo "assertions: $total"
if [ "$fail" -ne 0 ]; then
  echo "test-guard-protected: 失敗" >&2
  exit 1
fi
echo "test-guard-protected: すべて合格"
