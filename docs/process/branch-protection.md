# ブランチ保護と required check（運用手順）

3層強制（ADR-0004）の最終防衛線は **GitHub 側のブランチ保護**である。hooks は**そもそも Claude Code の
セッション内でしか発火しない**（手動の git 操作・CI・他ツール経由の変更には効かない）ため、ローカルを
すり抜けた変更を止める最後の砦がここになる。

> 補足（Round 9 で更新）: かつてここには「hooks はフェイルオープン（パーサ不在時は通す）」と書いていたが、
> 現在の guard-git.sh / guard-protected.sh は **jq も python3 も無い環境でも素通りさせず**、判定不能なときは
> **fail-closed（ブロック）** に倒す。したがって hooks が最終防衛線になり得ない理由は「フェイルオープンだから」
> ではなく「**発火する経路が限られるから**」である。
このファイルは、その**具体的な設定値**を再現可能な形で定義する（設定自体は GitHub 上の操作で、
リポジトリ内のコードからは行えないため手順として残す）。

> 決定そのもの（ブランチ保護を最終防衛線に置く）は ADR-0004。このファイルはその**運用パラメータ**。

## 対象ブランチ

- `main`（既定ブランチ）

## required status checks（必須チェック）

required に指定する名前は**ワークフロー名ではなく check run 名（＝ジョブ名）**である。

| 必須チェック名 | 由来 | 意味 |
|---|---|---|
| `quality-gate` | `.github/workflows/checks.yml` のジョブ `quality-gate`（`bash scripts/check.sh`） | 品質ゲートの単一入口（ADR-0004）。土台の自己検証・hooks 動作テスト・トレーサビリティ検査 |
| `conventional-commits` | `.github/workflows/pr-title.yml` のジョブ `conventional-commits` | PR タイトルが Conventional Commits 形式か（CLAUDE.md 原則2） |

> 補足: required に登録した名前は、その名前の check run が一度 GitHub 上に現れるまで候補に出ない。
> 初回は対象ワークフローを走らせた PR を1本作ってから登録すると確実。ジョブ名を変えたら
> ここと GitHub 設定の両方を更新する。

## 設定値（classic branch protection）

`main` に対して以下を有効化する:

- [x] **Require a pull request before merging**（main への直接 push を禁止 = CLAUDE.md 原則1）
  - Required approvals: 1（レビュー後マージ。CONTRIBUTING。ソロ運用で回らなければ 0 でも可、ただし PR 経由は維持）
- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - 必須チェック: `quality-gate` / `conventional-commits`（上表）
- [x] **Require conversation resolution before merging**（レビュー指摘の未解決を残さない。任意）
- [x] **Do not allow bypassing the above settings**（管理者にも保護を適用 = force push 禁止を実質化）
- [x] **Block force pushes**（force push 禁止 = CLAUDE.md 原則1・CONTRIBUTING）
- [x] **Restrict deletions**（保護ブランチの削除を禁止）

## 手順A: GitHub UI

1. リポジトリの **Settings → Branches → Add branch protection rule**。
2. Branch name pattern に `main`。
3. 上記チェックボックスを設定値どおりに有効化し、必須チェック 2 件を検索して追加。
4. **Create / Save changes**。

## 手順B: `gh` CLI（再現・監査用）

`OWNER/REPO` を対象に置き換えて実行する（要 admin 権限）。

```bash
gh api -X PUT repos/OWNER/REPO/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=quality-gate' \
  -f 'required_status_checks[contexts][]=conventional-commits' \
  -F 'enforce_admins=true' \
  -f 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'restrictions=' \
  -F 'allow_force_pushes=false' \
  -F 'allow_deletions=false'
```

現在値の確認（監査）:

```bash
gh api repos/OWNER/REPO/branches/main/protection | jq '{
  checks: .required_status_checks.contexts,
  strict: .required_status_checks.strict,
  enforce_admins: .enforce_admins.enabled,
  force_push: .allow_force_pushes.enabled,
  deletions: .allow_deletions.enabled
}'
```

## テンプレート派生リポジトリでの注意

deb をテンプレート複製した派生リポジトリには、この設定は**引き継がれない**（ブランチ保護は
リポジトリ設定でありコードに含まれないため）。複製直後にこの手順で `main` を保護すること。
`/stack-init` でスタック固有ゲートを check.sh に追加しても、それらは `quality-gate` 1件に内包されるため
required チェックの追加は不要（入口が単一化されている。ADR-0004）。
