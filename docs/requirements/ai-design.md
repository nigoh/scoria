# 要件仕様: AI 設計（BYOK）

- 責任者: 要求元=リポジトリオーナー / 実装責任=Claude / 検証責任=Claude
- 関連 ADR: ADR-0027
- 対象: 研究内容の自由記述から Claude API（利用者自身のキー）で拡張のブロックを設計し、
  既存の決定論ジェネレータでファイルに組み立てる機能

## 機能要件

### REQ-AI-001: 自由記述と設定からプロンプトを構築する

- 優先度: 高
- ユーザーストーリー: 研究者として、研究内容を自由文で書くだけで拡張の下書きを得たい。
  なぜならテンプレートは自分の研究手順と完全には一致しないから
- 受入基準（Acceptance Criteria）:
  - Given 拡張タイプ・出力言語・自由記述 When プロンプトを構築する Then それらすべてが
    プロンプト本文に反映される
  - Given 出力言語 en Then 生成物の本文を英語で書くよう指示が含まれる
  - Given 自由記述 Then 記述はユーザープロンプト側に置かれ、システムプロンプトには混ざらない
- 対応テスト: `Verifies: REQ-AI-001` を持つ `src/lib/ai/prompt.test.ts`

### REQ-AI-002: モデル応答を検証・正規化してから受け入れる

- 優先度: 高
- ユーザーストーリー: 利用者として、AI の応答が壊れていても画面が壊れないでほしい
- 受入基準（Acceptance Criteria）:
  - Given 構造が正しい応答 When 検証する Then name は kebab-case に正規化され、blocks は
    非空の label/content を持つ
  - Given name・description・blocks のいずれかが欠落・空・型不正の応答 Then 拒否され、
    理由つきのエラー結果になる（例外で落ちない）
- 対応テスト: `Verifies: REQ-AI-002` を持つ `src/lib/ai/parse.test.ts`

### REQ-AI-003: ファイルの組み立ては決定論ジェネレータが行う

- 優先度: 高
- ユーザーストーリー: 利用者として、AI 生成でも Claude Code の仕様に適合したファイルが欲しい
- 受入基準（Acceptance Criteria）:
  - Given 検証済みの AI 設計結果 When 拡張に変換する Then ファイルは既存の
    `regenerateFiles`（テスト済み）で組み立てられ、frontmatter の name が AI の name と一致する
  - Given AI の blocks Then すべて有効状態のブロックとして Step4 の編集対象になる
- 対応テスト: `Verifies: REQ-AI-003` を持つ `src/lib/ai/design.test.ts`

### REQ-AI-004: 失敗を利用者に分かる言葉で返す

- 優先度: 中
- ユーザーストーリー: 利用者として、キー誤り・拒否・過負荷を区別して次の行動を知りたい
- 受入基準（Acceptance Criteria）:
  - Given 401 Then 「API キーが無効」である旨のエラー結果
  - Given `stop_reason: "refusal"` Then 内容が拒否された旨のエラー結果（content は読まない）
  - Given 429 / 5xx / ネットワーク断 Then 再試行を促すエラー結果（例外で落ちない）
- 対応テスト: `Verifies: REQ-AI-004` を持つ `src/lib/ai/client.test.ts`

## 非機能要件（7カテゴリを一巡。対象外は明示）

| 分類 | ID | 内容 / 受入基準（測定可能な閾値＋根拠） | 対象外の場合の理由 |
|---|---|---|---|
| セキュリティ | NFR-SEC-001 | API キーは localStorage の設定ストアにのみ永続化し、履歴エントリ・生成ファイルに一切含まれない（文字列一致で 0 件） | |
| 信頼性 | NFR-REL-001 | 応答が非 JSON・型不正・空でも例外で落ちず、必ずエラー結果を返す（fail-closed） | |
| 性能・効率性 | — | | 対象外: 応答時間は Anthropic API 依存で制御不能。max_tokens 16000 の上限のみ設ける |
| 使用性 | — | | 対象外: 本ラウンドは E2E（モック）で操作導線のみ検証。定量指標は利用データ取得後に設定 |
| 保守性 | — | | 対象外: リポジトリ全体の品質ゲート（check.sh）で担保済み |
| 移植性 | — | | 対象外: 対応ブラウザは既存アプリと同一 |
| 運用性 | — | | 対象外: サーバーレス（BYOK）のため運用対象がない |

## 変更履歴（変更管理）

| 日付 | 変更 ID | 内容 | 理由 | 影響（DES/TEST） |
|---|---|---|---|---|
| 2026-08-02 | 初版 | AI 設計（BYOK）の要件を定義 | ADR-0027 | src/lib/ai/*.test.ts |
| 2026-08-14 | REQ-AI-001 文脈変更 | プロンプトのペルソナを研究ソフトウェア工学（RSE）に転換。要件の受入基準は不変 | ADR-0030（製品焦点の転換） | prompt.test.ts の文脈アサーション更新 |
