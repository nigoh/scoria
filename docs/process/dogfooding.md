# ドッグフーディング記録：/stack-init 予行演習

deb のプロセスと品質ゲートが実スタックで機能するかを、スクラッチ複製で end-to-end に検証した記録。
deb 本体はスタック非依存を保つ（ADR-0003）ため、検証は一時ディレクトリで行い、**得た学びだけ**を deb に反映する。

## 実施内容（2026-07）

最小 Node + TypeScript スタック（tsc + vitest）を導入し、プロセスを一巡させた:

1. **`/stack-init` 手順**: package.json / tsconfig(strict) を足場に、`scripts/check.sh` の
   「スタック固有のゲート」へ `npm run typecheck` / `npm run test` を配線
2. **`/spec`**: `docs/requirements/discount.md` に `REQ-DISCOUNT-001`＋NFR（7カテゴリ一巡・対象外明示）＋受入基準
3. **`/test-design`**: vitest テストに `Verifies: REQ-DISCOUNT-001, NFR-REL-001, NFR-MNT-001` を付与
4. 実装（純粋ロジック）→ `bash scripts/check.sh`

## 確認できたこと（プロセスは機能する）

- **トレーサビリティゲートが自動有効化**: `docs/requirements/` の出現で `check-traceability.sh` が起動し、
  「要件 3 件すべてに対応テストあり」で合格。要件ツリー外（tests/）の `Verifies:` を被覆と正しく判定。
- 宣言行（見出し／表）からの発行 ID 収集、受入基準の存在検査が実データで期待どおり動作。
- typecheck / vitest とスタックゲートが check.sh 単一入口から一括実行された。

## 発見した deb の欠陥と修正（予防活動）

- **workflow 構文チェックが package.json に依存していた**（このドッグフーディングで発見）:
  `.claude/workflows/*.js` はトップレベル return/await と `export const meta` を併用する
  （Workflow ツールが本体を async 関数でラップして実行する前提）。素の `node --check` は
  package.json の `type:module` 有無で結果が変わり、**スタック導入後に「構文エラー」と誤判定**していた。
  → `scripts/validate-foundation.sh` を「本体を async 関数でラップし export を外してから検査」に修正し、
  `scripts/test-validate-foundation.sh`（type:module 環境でも通る／壊れた workflow は捕捉）で再発防止。

## スタック側の学び（deb には持ち込まない）

- TypeScript は `@types/node` と `tsconfig` の `types`/`lib` 設定でハマりやすい（node グローバル・
  `asyncDispose` 等）。こうしたスタック固有の落とし穴は**各アプリ側**で解消し、ADR や rules に残す。
  deb はスタック非依存を保つため、特定スタックの recipe を土台には置かない（ADR-0003）。

> 教訓: 「土台の自己検証は、スタック導入後の環境（package.json あり）でも壊れないこと」を保証する。
> 新しい自己検証を足すときは type:module 環境での挙動も確認する。
