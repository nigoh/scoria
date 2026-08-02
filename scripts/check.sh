#!/usr/bin/env bash
# @file scripts/check.sh
# @brief 品質ゲートの唯一の入口（Stop フックと CI が同じこれを実行する）。
# @description
#   品質ゲートの唯一の入口。Stop フック（.claude/hooks/quality-gate.sh）と CI（.github/workflows/checks.yml）が
#   同じこのスクリプトを実行する。ゲートを追加するときは必ずここに足す（フックや CI に直書きしない）。
#
#   スタック導入後（/stack-init）は、この下に typecheck / lint / test を追記していく。
# @exitcode 0 すべてのゲートが合格
# @exitcode 1 いずれかのゲートが失敗
# @stdout 各ゲートの実行見出し（==> …）と最終判定
set -u

fail=0
# @description ゲートを1つ実行する。失敗しても中断せず fail フラグを立てるだけにして、
#   全ゲートを走らせてから結果をまとめて報告できるようにする。
# @internal
# @arg $@ string 実行するコマンドと引数
# @set fail int 実行が非ゼロで終わったら 1
# @stdout 実行見出し（==> コマンド）
# @stderr 失敗時に "NG: コマンド"
run() {
  echo "==> $*"
  if ! "$@"; then
    echo "NG: $*" >&2
    fail=1
  fi
}

cd "$(dirname "$0")/.." || exit 1

# 1. 土台の自己検証（steering 構成の構文・整合性）
run bash scripts/validate-foundation.sh

# 1b. hooks の動作テスト（擬似ツールコールでブロック/許可を検証）
run bash scripts/test-hooks.sh

# 1b'. guard-git の敵対的網羅（push 形の全変種・保護 ref 到達形・フェイルセーフの向き）
run bash scripts/test-guard-git.sh

# 1b''. guard-protected の敵対的網羅（.env/鍵/ロックファイル・ADR ガバナンス・パス形）
run bash scripts/test-guard-protected.sh

# 1b'''. 自己検証の再発防止（スタック導入後 = type:module でも壊れないこと）
run bash scripts/test-validate-foundation.sh

# 1c. 要件トレーサビリティ（ADR-0006。要件未定義なら対象なしで合格）
run bash scripts/check-traceability.sh

# 1d. トレーサビリティ検査の動作テスト（フィクスチャで正常/異常系を検証）
run bash scripts/test-traceability.sh

# 1e. ソースリファレンス（docs/reference.html）がソースの注釈と乖離していないか（ADR-0021）
#       gawk 不在では「検査不能」として落ちる（黙って合格にしない。気づきカード #40）
run bash scripts/build-docs.sh --check

# 1e'. リファレンス生成器の動作テスト（フィクスチャで正常/異常系・冪等性・乖離検知を検証）
run bash scripts/test-build-docs.sh

# 1e''. ドキュメント構成のピラミッド原則（結論先出し・図が先・用語の初出注釈。ADR-0022）
#         gawk 不在では「判定不能」を合格に倒さず落ちる（fail-closed）
run bash scripts/check-docs-structure.sh

# 1e'''. 構成検査そのものの動作テスト（フィクスチャで各検査の正常系/異常系を対で検証）
run bash scripts/test-docs-structure.sh

# 1f. MAPE-K 夜間セルフ改善の決定論部分の自己テスト（ADR-0010）
run bash mape/tests/run.sh

# 1f'. MAPE-K 知識ファイルの機械可読不変条件（DNA 完全性・fail-closed。ADR-0014）。
#      実データを検査する（テストは隔離 fixture）。knowledge/ が無い最小構成では検査しない。
if [ -d knowledge ]; then
  run bash -c '. mape/lib.sh && mape_verify_knowledge'
fi

# 1g. スキル/エージェント一覧（CLAUDE.md）と実体（.claude/）の同期
run bash scripts/check-skill-sync.sh

# 1g'. 同期検査の動作テスト（フィクスチャで正常/異常系を検証）
run bash scripts/test-skill-sync.sh

# 2. スタック固有のゲート（Vite + React + TypeScript。ADR-0024）
#    ここに足したゲートは Stop フックと CI の両方に自動で効く（check.sh が単一入口。ADR-0004）
run npm run typecheck
run npm run lint
run npm run format:check
run npm test

if [ "$fail" -ne 0 ]; then
  echo "品質ゲート失敗" >&2
  exit 1
fi
echo "品質ゲート合格"
