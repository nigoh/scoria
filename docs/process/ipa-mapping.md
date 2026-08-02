# IPA 概念 → deb 実装 トレーサビリティ表

インプットにした IPA/SEC の2ドキュメントの各概念を、deb のどの成果物に翻訳したかを追跡する表。
「取りこぼしゼロ」を担保するための対応表（このリポジトリ自身のトレーサビリティ管理）。

出典:
- **B** =「ソフトウェア開発の標準プロセス」（共通フレーム/SLCP、IPA/SEC）
- **A** =「高信頼化ソフトウェアのための開発手法ガイドブック」（IPA/SEC BOOKS）

## B: 共通フレーム / 超上流の提唱

| IPA 概念（出典） | deb での翻訳先 | 強制 |
|---|---|---|
| 共通フレーム＝プロセス体系・テーラリング | `docs/process/README.md`, `lifecycle.md`（テーラリング基準） | docs |
| ①利害関係者の役割と責任分担の明確化 | `requirements.md`（役割と責任） | docs |
| ②多段階の見積り方式（再見積り） | `lifecycle.md`（見積り・スコープは各ゲートまで暫定、ゲートで見直す）。見積り自動化は対象外 | docs |
| ③V字モデルの採用 | ADR-0005 / `lifecycle.md`（V字図・段階ゲート） | docs + ゲート |
| ④超上流における準委任契約の採用 | 人間専用領域。翻訳せず（方針: 契約は環境の対象外） | 対象外 |
| ⑤要件の合意及び変更ルールの事前確立 | `requirements.md`（変更管理）／ADR-0006 | docs + CI |
| ⑥非機能要件の重視 | `requirements.md`（NFR カテゴリ一巡）／`/spec` | docs + ゲート |
| ⑦運用・保守を含めた SLCP | `lifecycle.md`（運用・保守段階）／`/postmortem` | docs |
| なぜプロセスが重要か（属人性の排除・再現性） | `README.md`（プロセス定義）／機構化全般 | docs |

## A: 高信頼化ソフトウェアの開発手法

| IPA 概念（出典・章） | deb での翻訳先 | 強制 |
|---|---|---|
| ディペンダビリティ／定量的マネジメント（1章） | `verification.md`（定量品質） | docs |
| 品質特性（2章） | `requirements.md`（NFR 7分類） | docs |
| システムプロファイル＝重要度による厳格さの校正（2.2） | `lifecycle.md`（テーラリング軸1: 対象の重要度。高影響領域はゲート引き上げ） | docs + ゲート |
| 予防活動と検知活動の整理（3章） | ADR-0007 / `verification.md` | docs |
| レビューとテストの欠陥検出戦略の統合（3.2） | `verification.md`（役割分担表）／`code-reviewer` | docs + レビュー |
| レビュー手法（3.2.2）＝チェックリスト/観点駆動・欠陥の工程間持ち越し | `code-reviewer`（観点内蔵）／`verification.md`（レビュー技法） | レビュー |
| 障害影響度指標（4章コラム） | `templates/postmortem.md`（影響度分類欄。重要度と接続） | template |
| テスト技法の概要（3.2.3） | `/test-design` / `verification.md`（技法） | skill |
| 障害事例から学ぶ予防活動・再発防止（4章） | `/postmortem` / `verification.md`（予防活動） | skill |
| 代用特性展開（4.3） | `verification.md`（代用特性の考え方） | docs |
| トレーサビリティ管理・QFD（5章） | ADR-0006 / `traceability.md` / `check-traceability.sh` | docs + CI |
| 顧客要件一覧・要求品質の優先順位（5.5） | `templates/requirement-spec.md`（優先度欄） | template |
| テスト網羅性の高度化（6章） | `/test-design` / `verification.md`（観点・アーキテクチャ） | skill |
| テスト観点・テストアーキテクチャ（6.2） | `/test-design`（観点→レベル割付） | skill |
| 直交表・組み合わせテスト（6.3.1） | `verification.md`（直交表/ペアワイズ）／`/test-design` | skill |
| シナリオテスト（6.3.2） | `verification.md`（シナリオ）／`/test-design` | skill |
| 事例編（各社の W モデル・HAYST・見積り等、2部） | 参考知見として本表に集約。個別導入は各アプリの `/stack-init` 時に判断 | 参考 |

## 「対象外」とした概念とその理由

- **準委任契約・請負契約**（B④）: 商取引の領域で、開発環境の機構では強制も表現もできない。
  必要な組織は自組織の契約規程で扱う。
- **各社事例の固有ツール**（A 2部）: 特定製品・組織に依存。deb はスタック非依存（ADR-0003）のため、
  手法の"考え方"のみ抽出し、実装は各アプリ側の裁量とする。

> この表は「厳格さ」の証跡でもある。IPA の提唱をどう扱ったか（翻訳／ゲート化／対象外）を明示し、
> 黙って落とした概念がないことを担保する。新しい知見を取り込んだら、この表に行を足す。
