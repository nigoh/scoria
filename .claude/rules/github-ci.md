---
paths:
  - ".github/**"
---

# GitHub / CI 規約

- CI（checks.yml）は品質ゲートとして `bash scripts/check.sh` を実行する。CI に個別のチェックを直書きせず、check.sh / validate-foundation.sh 側に足す。
- workflow の `permissions:` ブロックを書く場合、列挙しなかったスコープはすべて落ちる。checkout には `contents: read` が必要（過去の学び）。
- PR タイトルは Conventional Commits 形式（pr-title.yml が検証）。形式: `feat|fix|docs|test|refactor|chore|ci(scope): subject`（破壊的変更は `!` を付ける: `feat(scope)!: ...`）
- ラベル・テンプレートを変更したら CONTRIBUTING.md の記述と同期する。
