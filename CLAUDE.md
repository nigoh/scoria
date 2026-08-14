# Scoria — 学術研究向け Claude Code 拡張ジェネレータ

研究テーマと目的を入力すると、Claude Code の**スキル・エージェント・プラグイン**をウィザードで生成し
ZIP でダウンロードできる Web アプリ。開発の進め方は deb 由来の土台に従う（ADR-0024）。
設計判断は docs/adr/ を参照（覆さない。覆すなら新 ADR）。

## 構成

- `src/` … アプリ本体（レイヤ規約は `.claude/rules/frontend.md`）
- `e2e/` … Playwright の E2E テスト
- `.claude/` … steering 一式（rules / skills / agents / workflows / hooks / settings）。案内は `.claude/README.md`
- `docs/adr/` … 意思決定記録（index: docs/adr/README.md）
- `docs/process/` … 開発プロセス定義（V字・段階ゲート・要件・トレーサビリティ・検証）
- `docs/requirements/` … 要件仕様（REQ/NFR。`check-traceability.sh` が被覆を検証）
- `docs/reference.html` … 開発基盤スクリプトのリファレンス（`scripts/build-docs.sh` が生成。手で編集しない）
- `scripts/check.sh` … **品質ゲートの唯一の入口**（Stop フックと CI が同じものを実行する）
- `mape/` … MAPE-K セルフ改善の決定論スクリプト（ADR-0010。手動起動のみ。ADR-0023）
- `knowledge/` … MAPE-K 共有ナレッジ K（案内は `knowledge/README.md`）

### ディレクトリ詳細（src/）

```
main.tsx              # React エントリーポイント
App.tsx               # ルートコンポーネント（Provider 束ね）
index.css             # グローバルCSS + デザイントークン
types/index.ts        # 全機能で共有する型定義
routes/               # ルーティング（home / builder / graph / privacy / terms）
features/
  home/               # ランディング（Hero・StepFlow・UseCase・TutorialCTA）
  builder/            # ウィザード本体
    steps/            # Step1ExtensionType 〜 Step4Content
    HooksEditor / McpEditor / PreviewPanel / FileTreeView など
  graph/              # 論文グラフ探索（検索→類似グラフ→AI 設計へ引き渡し。ADR-0028）
components/
  ui/                 # shadcn/ui（Radix ベース）
  layout/             # AppShell, PageContainer
  illustrations/      # SVG イラスト
stores/               # zustand（wizard / extension / history）
lib/                  # generator, templates, constants, cli, zip, utils
  ai/                 # AI 設計（BYOK。プロンプト構築・応答検証・決定論組み立て。ADR-0027）
  graph/              # 論文グラフ（OpenAlex クライアント・類似度・レイアウト。ADR-0028）
```

## 技術スタック

- **ビルド:** Vite / **言語:** TypeScript（`strict: true`、パスエイリアス `@/` → `src/`）
- **UI:** React 19 + shadcn/ui（Radix UI）+ Tailwind CSS v4 + Phosphor Icons
- **デザイン:** コンソール方向（ADR-0026）。色は `src/index.css` のトークンが正本で、
  個別コンポーネントに色を直書きしない。角丸 0・等幅が既定・琥珀は主アクション専用
- **状態:** zustand / **ルーティング:** react-router-dom v7 / **ZIP:** JSZip / **DnD:** dnd-kit
- **AI:** @anthropic-ai/sdk（BYOK・ブラウザ直呼び。キーは localStorage のみ。ADR-0027）
- **論文データ:** OpenAlex（CC0・キー不要・ブラウザ直呼び・mailto 付き。ADR-0028）
- **テスト:** Vitest（ユニット）+ Playwright（E2E）
- **リンタ/フォーマッタ:** ESLint (flat config) / Prettier
- **デプロイ:** Cloudflare Pages（`wrangler.jsonc`）

## 絶対原則（hooks と CI でも強制される。ADR-0004）

1. **main に直接コミット・プッシュしない**。トピックブランチ + PR 経由（force push も禁止）
2. コミット件名・PR タイトルは **Conventional Commits**: `feat|fix|docs|test|refactor|chore|ci(scope): subject`
3. **設計・技術・運用の決定は ADR に記録する**（`/adr`）。main マージ後の ADR は編集せず新 ADR で supersede
4. **品質ゲートを弱めない**。ゲートは scripts/check.sh に足す（フックや CI に直書きしない）
5. `.env`・鍵ファイル・ロックファイルを直接編集しない（ロックファイルはパッケージマネージャで再生成）

## ビルド / 検証

```bash
bash scripts/check.sh   # 品質ゲート一括（土台の自己検証 + typecheck/lint/format:check/test）

npm run dev             # 開発サーバー
npm run build           # 本番ビルド（tsc && vite build）
npm test                # Vitest（npm run test:watch でウォッチ）
npx playwright test     # E2E（Playwright）
npm run typecheck       # 型チェック
npm run lint            # ESLint（lint:fix で自動修正）
npm run format          # Prettier で整形（format:check で検査）
```

`scripts/check.sh` にゲートを足せば Stop フックと CI の両方に効く。個別に直書きしない。

## 開発プロセス（V字モデル＋段階ゲート。ADR-0005〜0007）

厳格なプロセス定義は `docs/process/`（企画→要件定義→設計→実装→テスト→運用のV字と段階ゲート）。
変更規模に応じてテーラリング（省略）してよい（`docs/process/lifecycle.md`）。IPA 概念との対応は
`docs/process/ipa-mapping.md`。要件は ID（REQ/NFR/DES/TEST）で管理し `Verifies:` で追跡する。

## スキル（`/name` で明示起動）

| コマンド | 用途 |
|---|---|
| `/round` | 開発ラウンドの開始・振り返り（スコープ合意・気づきの規約反映） |
| `/spec` | 超上流の要件定義（機能/非機能要件・受入基準・ID 採番）。実装前ゲート |
| `/test-design` | テスト網羅性の設計（観点→アーキテクチャ→直交表/シナリオ） |
| `/postmortem` | 障害の予防活動（原因分析→再発防止テスト→規約反映） |
| `/adr` | 設計判断を ADR 化（連番・テンプレート・index 更新） |
| `/fix` | 設計に分岐のある修正: 複数案アーティファクト提示 → 選択 → 忠実実装 |
| `/orchestrate` | 名前付きワークフローの決定論的実行（下表） |
| `/stack-init` | 技術スタックの導入。**Scoria では実行済み**（ADR-0024）。再スタック時のみ使う |
| `/feedback` | 土台利用中の気づきを本家 deb にイシューで送る（上流改善。ADR-0009） |
| `/mape` | MAPE-K セルフ改善。`night`=M→A→P で改善案を計画イシューに掲示（読み取り・安全）／`execute`=承認項目を1周1件だけ実装。ADR-0010/0018 |

## エージェント

| エージェント | 権限 | 役割 |
|---|---|---|
| requirements-analyst | 読み書き | 超上流の要件定義（REQ/NFR/受入基準の構造化） |
| implementer | 読み書き | 1スコープの隔離実装（/fix の実装フェーズ等） |
| test-designer | 読み書き | テスト観点・網羅性設計（直交表/ペアワイズ/シナリオ） |
| test-engineer | 読み書き | テスト実装・red→green |
| test-runner | 読み書き | Vitest/Playwright の実行・失敗の切り分け・回帰検知 |
| code-reviewer | Write/Edit なし | 差分レビュー（正確性・規約・設計・要件整合・テスト） |
| process-auditor | Write/Edit なし | プロセス遵守監査（段階ゲート・トレーサビリティ・NFR一巡） |
| doc-auditor | Write/Edit なし | ドキュメント整合性（一覧同期・ADR index・乖離） |
| rule-auditor | Write/Edit なし | 規約監査と go/no-go 判定（PR 前） |

## ワークフロー（.claude/workflows/、/orchestrate で起動）

| ワークフロー | 用途 |
|---|---|
| understand | 領域横断の並列調査 → 統合回答 |
| bug-hunt | 観点レンズ並列探索 → 敵対的検証 → 確定バグのみ |
| quality-gates | PR 前品質ゲート並列実行（reviewer / doc / rule / process + check.sh） |

## 開発フロー（ADR-0002 / 0005）

1. `/round` でラウンドを開始し、スコープと non-goals を合意する
2. 中〜大の変更は `/spec` で要件定義（実装前ゲート）→ `/test-design` でテスト設計。自明な変更は省略可
3. 設計に分岐のある修正は `/fix`、障害対応は `/postmortem`
4. 純粋ロジック・重要度高の実装は test-first（赤を観測→緑→refactor）を標準リズムとする（ADR-0013）
5. 実装後は `bash scripts/check.sh` の緑を確認（Stop フックでも強制される）
6. PR 前に `/orchestrate quality-gates` で多角監査（軽い変更なら rule-auditor 単体でよい）
7. PR はドラフトで作成し、レビュー後にマージ。ラウンド終了時は `/round close` で振り返る

> 手順・チェックリストはここに書かず .claude/skills/ へ。領域規約は .claude/rules/ へ。
> このファイルは恒常的な事実のみ・200行未満を保つ（validate-foundation.sh が検証する）。
