# 0004: ルールの3層強制と品質ゲートの単一入口

- Status: Accepted
- Date: 2026-07-17
- Deciders: リポジトリオーナー

## Context（背景）

ドキュメントに書いただけのルールは、コンテキストの長いセッションで破られる。
一方、強制をフックや CI に散らすと、ゲートの重複・抜け・不整合が生じる。

## Decision（決定）

1. **3層強制**: 守らせたいルールは (a) ドキュメント（CLAUDE.md / rules、助言）、
   (b) hooks（PreToolUse/Stop の exit 2、実行時ブロック）、(c) CI（機械検証）の3層に重ねて置く。
   例: main 直接 push 禁止 = CLAUDE.md + guard-git.sh + permissions.deny（+ GitHub ブランチ保護）
2. **単一入口**: 品質ゲートは `scripts/check.sh` を唯一の入口とし、Stop フック（quality-gate.sh）と
   CI（checks.yml）は check.sh を呼ぶだけにする
3. **自己検証**: steering 構成自体を `scripts/validate-foundation.sh` で機械検証する（土台が自分をテストする）
4. hooks はフェイルオープン（パーサ不在時は通す）とし、最終防衛線は GitHub 側のブランチ保護に置く
5. ブロックする hooks は必ず「代わりに何をすべきか」を stderr で案内する

## Options Considered（検討した選択肢）

### 案1: 3層強制 + 単一入口（採用）

- 長所: ルールが確実に効く。ゲート追加が check.sh への1行で済む。ローカルと CI の判定が一致する
- 短所: 同じルールを複数箇所に書く冗長さ（→ validate-foundation.sh で同期を検証して緩和）

### 案2: ドキュメントのみ（hooks なし）

- 長所: 構成が単純
- 短所: 長いセッションでルールが忘れられ、破られたことに気づけない

## Consequences（結果）

- Stop フックにより「壊れたまま作業を終える」ことができなくなる
- **再検討のトリガー**: check.sh の実行時間が Stop フックの体感を損ねるほど伸びたら、差分実行やキャッシュ強化を検討する
