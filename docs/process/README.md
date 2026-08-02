# 開発プロセス（deb）

deb の開発プロセスを厳格に定義する。IPA/SEC の標準プロセス（共通フレーム/SLCP）と高信頼化手法を
Claude Code の土台に翻訳したもの。設計判断は ADR-0005〜0007、由来の対応は `ipa-mapping.md` を参照。

> このディレクトリは「恒久的なプロセス定義」を置く。ラウンド固有の手順は `.claude/skills/` に、
> 領域規約は `.claude/rules/` に置く（機構配置は ADR-0001）。

## プロセスの全体像

```
企画 ─▶ 要件定義 ─▶ 設計 ─▶ 実装 ─▶ テスト ─▶ 運用・保守
                    （V字モデルで左右を対応づける。ADR-0005）
```

| ドキュメント | 内容 | 対応 ADR |
|---|---|---|
| [lifecycle.md](lifecycle.md) | V字モデル・段階ゲート・テーラリング基準 | ADR-0005 |
| [requirements.md](requirements.md) | 超上流（機能/非機能要件・受入基準・変更管理・役割） | ADR-0006 |
| [traceability.md](traceability.md) | ID 体系と要件→設計→実装→テストの追跡規約 | ADR-0006 |
| [verification.md](verification.md) | 予防活動・検知活動・レビュー/テスト統合・定量品質 | ADR-0007 |
| [branch-protection.md](branch-protection.md) | ブランチ保護・required check の具体設定値（3層強制の最終防衛線） | ADR-0004 |
| [ipa-mapping.md](ipa-mapping.md) | IPA 概念 → deb 実装のトレーサビリティ表 | — |
| [dogfooding.md](dogfooding.md) | /stack-init 予行演習の記録（プロセスの実効性検証・発見した欠陥） | — |
| [templates/](templates/) | 要件仕様・テスト設計・ポストモーテム・トレーサビリティ表の雛形 | — |

## 機構との接続

| プロセス活動 | deb の入口 |
|---|---|
| ラウンドの開始・段階合意 | `/round`（ADR-0002） |
| 要件定義（超上流） | `/spec` → `docs/requirements/` |
| テスト設計（網羅性） | `/test-design` |
| 予防活動（再発防止） | `/postmortem` |
| 検知活動（レビュー） | `code-reviewer` エージェント（レビュー観点を内蔵） |
| 段階ゲート・品質ゲート | `scripts/check.sh`（`check-traceability.sh` を含む） |
| 設計判断の記録 | `/adr` |

## テーラリング（重要）

このプロセスは**変更規模に応じて省略してよい**（共通フレームの修整思想、ADR-0005）。
自明な修正（typo・明白な1行バグ）は要件定義・設計を省き、実装＋再発防止テストのみでよい。
省略の判断基準は [lifecycle.md](lifecycle.md) のテーラリング（変更規模 × 対象の重要度の2軸）に従う。**厳格さは重さではなく、
「省略したことを意識的に選ぶ」ことにある。**

## 土台の導入手順（テンプレート運用）

deb は**コピーして使う土台リポジトリ**である（ADR-0003）。CI・hooks・`scripts/check.sh`・`docs/process`・
ADR はリポジトリ常駐で初めて機能するため、プラグインではなくテンプレート複製で導入する。

1. **複製**: GitHub の "Use this template"（配布元は Settings → General → "Template repository" を ON）、
   または `gh repo create <owner>/<app> --template nigoh/deb`。
2. **初期確認**: セッションを開くと SessionStart フックが状態を表示する。`bash scripts/check.sh` が緑なことを確認する
   （土台の自己検証・hooks 動作テスト・トレーサビリティ検査。この時点では要件未定義なので「対象なし＝合格」）。
2b. **ブランチ保護**: `main` を保護し required check を登録する（[branch-protection.md](branch-protection.md)）。
   hooks はフェイルオープンなので、この GitHub 側設定が最終防衛線になる（ADR-0004）。
3. **スタック導入**: `/stack-init` を一度だけ実行する。技術選定を ADR 化し、`scripts/check.sh` に
   typecheck/lint/test を配線し、領域 rules を追加する。テストは `Verifies: <要件ID>` を書ける形にする。
4. **プロジェクト固有化**: `CLAUDE.md`・`README`・`CONTRIBUTING` をアプリの内容へ書き換える。
   founding ADR（docs/adr/README.md 参照）はそのまま残す（土台の設計判断）。以降の決定は `/adr` で追記する。
5. **開発開始**: `/round` でラウンドを開始し、中〜大の変更は `/spec`→`/test-design`→実装→`/orchestrate quality-gates`
   の流れで回す（テーラリングで軽い変更は省略可）。

> 既存リポジトリに steering の一部（skills/agents）だけ持ち出したい場合はプラグイン化も可能だが、
> その場合 CI 強制・`docs/process`・トレーサビリティゲートは付いてこない（＝機械強制は薄まる）。
> 厳格なプロセスを丸ごと効かせたいならテンプレート複製を使う。
