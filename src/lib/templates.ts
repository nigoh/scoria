import type { TemplateId, ExtensionType } from "@/types";

export interface TemplateContent {
  defaultName: string;
  defaultDescription: string;
  blocks: { label: string; content: string }[];
}

type TemplateMap = Record<TemplateId, Record<ExtensionType, TemplateContent>>;

function skillContent(
  name: string,
  description: string,
  blocks: { label: string; content: string }[],
): TemplateContent {
  return { defaultName: name, defaultDescription: description, blocks };
}

function agentContent(
  name: string,
  description: string,
  blocks: { label: string; content: string }[],
): TemplateContent {
  return { defaultName: name, defaultDescription: description, blocks };
}

function pluginContent(
  name: string,
  description: string,
  blocks: { label: string; content: string }[],
): TemplateContent {
  return { defaultName: name, defaultDescription: description, blocks };
}

export const TEMPLATE_CONTENTS: TemplateMap = {
  systematic_review: {
    skill: skillContent(
      "systematic-review",
      "PRISMA準拠の系統的文献レビューを実行する",
      [
        {
          label: "役割設定",
          content:
            "あなたは系統的文献レビューの専門家です。PRISMA 2020ガイドラインに準拠し、エビデンスに基づいた包括的な文献レビューを支援します。",
        },
        {
          label: "タスク指示",
          content: `ユーザーが指定した研究テーマについて、以下の手順で系統的文献レビューを支援してください：

1. **研究課題の明確化**: PICO/PECOフレームワークで研究課題を構造化
2. **検索戦略の策定**: 主要データベース（PubMed, Scopus, Web of Science等）向けの検索式を作成
3. **スクリーニング基準**: 包含・除外基準を提案
4. **データ抽出テンプレート**: 必要な抽出項目を提案
5. **バイアス評価**: 適切なバイアスリスク評価ツール（RoB 2, ROBINS-I等）を推奨

$ARGUMENTS を研究テーマとして使用してください。`,
        },
        {
          label: "出力フォーマット",
          content: `以下の構造で出力してください：
- PICO/PECO分解表
- データベースごとの検索式
- 包含/除外基準リスト
- PRISMAフローダイアグラムの各段階の説明
- データ抽出テンプレート（表形式）`,
        },
        {
          label: "品質ガードレール",
          content: `- 検索式は再現可能性を確保してください
- エビデンスレベルを明示してください
- 未検証の主張にはその旨を注記してください
- 実際のデータベース検索は研究者自身が行う必要がある点を明記してください`,
        },
      ],
    ),
    agent: agentContent(
      "systematic-review-agent",
      "系統的文献レビューの各ステップを自律的に支援するエージェント",
      [
        {
          label: "役割・専門性",
          content:
            "あなたは系統的文献レビューを専門とする学術研究支援エージェントです。PRISMA 2020、Cochrane Handbookの方法論に精通しています。",
        },
        {
          label: "行動指針",
          content: `以下のワークフローに従って自律的に作業してください：

1. ユーザーのリサーチクエスチョンを分析し、PICO/PECOフレームワークで構造化
2. プロジェクトディレクトリ内のファイルを確認し、既存のレビュープロトコルがあれば読み込む
3. 検索戦略を策定し、Markdownファイルとして保存
4. スクリーニング基準と抽出テンプレートをファイルに出力
5. 進捗を報告し、次のステップの指示を求める

ファイル操作はRead/Write/Editツールを使用してください。`,
        },
        {
          label: "制約事項",
          content: `- 実際のデータベース検索結果を捏造しないでください
- 不確実な情報には必ず注記をつけてください
- ファイルの上書き前に確認してください`,
        },
      ],
    ),
    plugin: pluginContent(
      "systematic-review",
      "系統的文献レビューを包括的に支援するプラグインパッケージ",
      [
        {
          label: "スキル本文",
          content:
            "PRISMA 2020ガイドラインに準拠した系統的文献レビューを支援します。PICO分解、検索戦略策定、スクリーニング基準の設定、データ抽出テンプレート作成を一貫してサポートします。",
        },
        {
          label: "エージェント本文",
          content:
            "系統的文献レビューの各ステップを自律的に実行するエージェントです。プロトコル作成からデータ抽出テンプレートまで、ファイル操作を伴う作業を担当します。",
        },
        {
          label: "CLAUDE.md ガイド",
          content: `## 系統的文献レビュー プロジェクト

### ワークフロー
1. /systematic-review でレビュープロトコルを生成
2. 検索戦略の確認・修正
3. スクリーニングの実行と記録
4. データ抽出とバイアス評価

### ファイル構成
- protocol/ — レビュープロトコル
- search/ — 検索戦略・結果
- screening/ — スクリーニング記録
- extraction/ — データ抽出結果`,
        },
      ],
    ),
  },

  meta_analysis: {
    skill: skillContent("meta-analysis", "メタ分析の設計と効果量計算を支援する", [
      {
        label: "役割設定",
        content:
          "あなたはメタ分析の専門家です。効果量の計算、異質性の評価、フォレストプロットの解釈を支援します。",
      },
      {
        label: "タスク指示",
        content: `ユーザーが提供するデータに基づいて、メタ分析を支援してください：

1. **効果量の選択**: 研究デザインに適した効果量指標（Cohen's d, OR, RR等）を推奨
2. **異質性評価**: I², Q統計量, τ²の解釈ガイド
3. **モデル選択**: 固定効果 vs ランダム効果モデルの選択基準
4. **出版バイアス**: ファンネルプロットやEgger's testの解釈
5. **感度分析**: Leave-one-out分析やサブグループ分析の設計

$ARGUMENTS をテーマとして使用してください。`,
      },
      {
        label: "出力フォーマット",
        content: `- 推奨効果量指標とその理由
- 統計的異質性の解釈ガイド
- 分析計画書（テンプレート）
- 結果報告のチェックリスト`,
      },
    ]),
    agent: agentContent(
      "meta-analysis-agent",
      "メタ分析の設計・実行を自律的に支援するエージェント",
      [
        {
          label: "役割・専門性",
          content:
            "あなたはメタ分析の統計手法に精通した研究支援エージェントです。Cochrane統計ガイドラインに従います。",
        },
        {
          label: "行動指針",
          content: `1. データファイルを読み込み、研究の構造を把握
2. 適切な効果量指標を提案
3. 分析コード（R/Python）のテンプレートを生成
4. 結果の解釈ガイドを作成`,
        },
        {
          label: "制約事項",
          content: `- 統計結果を捏造しないでください
- コードは実行可能かつ再現可能なものにしてください`,
        },
      ],
    ),
    plugin: pluginContent("meta-analysis", "メタ分析を包括的に支援するプラグインパッケージ", [
      {
        label: "スキル本文",
        content:
          "メタ分析の効果量計算、異質性評価、出版バイアス検定を支援します。研究デザインに応じた分析戦略を提案します。",
      },
      {
        label: "エージェント本文",
        content:
          "メタ分析の設計から結果解釈まで自律的に支援するエージェントです。データファイルの読み込みと分析コード生成を担当します。",
      },
      {
        label: "CLAUDE.md ガイド",
        content: `## メタ分析プロジェクト

### ワークフロー
1. /meta-analysis で分析計画を作成
2. データ抽出と効果量計算
3. 統計分析の実行
4. 結果の視覚化と報告`,
      },
    ]),
  },

  citation_check: {
    skill: skillContent(
      "citation-check",
      "論文の引用整合性と参考文献リストを検証する",
      [
        {
          label: "役割設定",
          content:
            "あなたは学術出版の品質管理専門家です。引用の正確性、参考文献リストの完全性、書式の一貫性を検証します。",
        },
        {
          label: "タスク指示",
          content: `論文ファイルを分析し、以下の観点で引用チェックを行ってください：

1. **本文中引用と参考文献リストの照合**: 未引用・未収録の不一致を検出
2. **引用形式の一貫性**: APA/Vancouver/IEEE等の書式準拠を確認
3. **自己引用率**: 自己引用の割合を算出
4. **引用の適切性**: 主張と引用文献の関連性を評価
5. **最新性**: 引用文献の年代分布を分析

$ARGUMENTS を対象ファイルパスとして使用してください。`,
        },
        {
          label: "出力フォーマット",
          content: `- 不一致リスト（本文引用 vs 参考文献リスト）
- 書式エラーリスト
- 引用統計サマリー（総数、年代分布、自己引用率）
- 改善提案リスト`,
        },
      ],
    ),
    agent: agentContent(
      "citation-check-agent",
      "論文の引用を自動検証するエージェント",
      [
        {
          label: "役割・専門性",
          content:
            "学術出版における引用検証を専門とするエージェントです。主要な引用スタイル（APA 7th, Vancouver, IEEE）に精通しています。",
        },
        {
          label: "行動指針",
          content: `1. 対象ファイルを読み込み、引用パターンを抽出
2. 参考文献リストを解析
3. 本文引用と参考文献の照合を実行
4. レポートファイルを生成して保存`,
        },
        {
          label: "制約事項",
          content: `- ファイルの内容を変更せず、レポートのみ出力してください
- 不確実な指摘には信頼度を付記してください`,
        },
      ],
    ),
    plugin: pluginContent(
      "citation-check",
      "引用チェックを包括的に支援するプラグインパッケージ",
      [
        {
          label: "スキル本文",
          content:
            "論文の引用整合性を検証し、参考文献リストの完全性・書式一貫性をチェックします。",
        },
        {
          label: "エージェント本文",
          content: "論文ファイルを読み込み、引用検証レポートを自動生成するエージェントです。",
        },
        {
          label: "CLAUDE.md ガイド",
          content: `## 引用チェックプロジェクト

### 使い方
1. /citation-check [ファイルパス] で検証開始
2. レポートを確認して修正`,
        },
      ],
    ),
  },

  methodology_advisor: {
    skill: skillContent(
      "methodology-advisor",
      "研究デザインと統計手法の選定をガイドする",
      [
        {
          label: "役割設定",
          content:
            "あなたは研究方法論の専門家です。定量・定性・混合研究法に精通し、適切な研究デザインの選定を支援します。",
        },
        {
          label: "タスク指示",
          content: `ユーザーの研究目的に基づいて、最適な研究手法を提案してください：

1. **研究デザインの推奨**: RCT、コホート、ケーススタディ等から最適な選択肢を提示
2. **サンプルサイズ計算**: 検出力分析に基づくサンプルサイズの目安
3. **データ収集法**: アンケート、インタビュー、観察等の手法比較
4. **分析手法**: 統計手法や質的分析手法の推奨
5. **妥当性・信頼性**: 内的・外的妥当性の確保方法

$ARGUMENTS を研究テーマとして使用してください。`,
        },
        {
          label: "出力フォーマット",
          content: `- 推奨研究デザイン（理由付き）
- 手法比較表
- サンプルサイズの目安
- 分析計画のアウトライン`,
        },
      ],
    ),
    agent: agentContent(
      "methodology-advisor-agent",
      "研究方法論の選定を対話的に支援するエージェント",
      [
        {
          label: "役割・専門性",
          content: "研究方法論の専門家として、研究デザインから分析手法まで包括的に助言します。",
        },
        {
          label: "行動指針",
          content: `1. 研究目的と制約条件をヒアリング
2. 候補となる研究デザインを比較提示
3. 選択されたデザインの詳細計画を策定
4. 計画書をファイルとして出力`,
        },
        {
          label: "制約事項",
          content: `- 倫理審査の要件について注意喚起してください
- 手法の限界を必ず言及してください`,
        },
      ],
    ),
    plugin: pluginContent(
      "methodology-advisor",
      "研究手法の選定を支援するプラグインパッケージ",
      [
        {
          label: "スキル本文",
          content: "研究デザインと統計手法の選定をガイドし、研究計画の立案を支援します。",
        },
        {
          label: "エージェント本文",
          content:
            "研究方法論の専門家として、研究デザインの選定から分析計画の策定までを対話的に支援します。",
        },
        {
          label: "CLAUDE.md ガイド",
          content: `## 研究手法アドバイザー

### ワークフロー
1. /methodology-advisor で手法選定を開始
2. 研究デザインの比較検討
3. 分析計画の策定`,
        },
      ],
    ),
  },

  paper_structure: {
    skill: skillContent(
      "paper-structure",
      "IMRaD形式に沿った論文構成のアウトラインを生成する",
      [
        {
          label: "役割設定",
          content:
            "あなたは学術論文執筆の専門家です。IMRaD形式やジャーナルの投稿規程に精通し、論文構成の最適化を支援します。",
        },
        {
          label: "タスク指示",
          content: `研究内容に基づいて論文のアウトラインを生成してください：

1. **タイトル候補**: 3つの候補を提案
2. **アブストラクト構成**: 構造化アブストラクトのテンプレート
3. **Introduction**: 背景→先行研究→ギャップ→目的の流れ
4. **Methods**: 研究デザインに応じた記載項目
5. **Results**: 図表構成の提案
6. **Discussion**: 主要所見→先行研究との比較→限界→意義

$ARGUMENTS を研究テーマとして使用してください。`,
        },
        {
          label: "出力フォーマット",
          content: `- 各セクションの構成案（箇条書き）
- 推奨図表リスト
- パラグラフの流れの概要`,
        },
      ],
    ),
    agent: agentContent(
      "paper-structure-agent",
      "論文構成の策定と執筆支援を行うエージェント",
      [
        {
          label: "役割・専門性",
          content: "学術論文の構成・執筆支援を専門とするエージェントです。",
        },
        {
          label: "行動指針",
          content: `1. 既存のドラフトや研究メモを読み込む
2. 論文のアウトラインを生成してファイルに保存
3. 各セクションの詳細構成を提案
4. ドラフトへのフィードバックを提供`,
        },
        {
          label: "制約事項",
          content: `- 論文の内容を捏造しないでください
- フィードバックは建設的で具体的にしてください`,
        },
      ],
    ),
    plugin: pluginContent(
      "paper-structure",
      "論文構成の策定を包括的に支援するプラグインパッケージ",
      [
        {
          label: "スキル本文",
          content: "IMRaD形式に沿った論文のアウトラインとセクション構成を生成します。",
        },
        {
          label: "エージェント本文",
          content:
            "論文のドラフトを読み込み、構成改善の提案やアウトライン生成を自律的に行うエージェントです。",
        },
        {
          label: "CLAUDE.md ガイド",
          content: `## 論文構成支援プロジェクト

### ワークフロー
1. /paper-structure で構成案を生成
2. セクションごとに詳細化
3. ドラフトの構成レビュー`,
        },
      ],
    ),
  },

  search_strategy: {
    skill: skillContent(
      "search-strategy",
      "学術データベース向けの検索クエリ・戦略を策定する",
      [
        {
          label: "役割設定",
          content:
            "あなたは学術情報検索の専門家です。PubMed, Scopus, Web of Science等の検索構文に精通し、再現可能な検索戦略を策定します。",
        },
        {
          label: "タスク指示",
          content: `研究テーマに基づいて、学術データベース向けの検索戦略を策定してください：

1. **概念分解**: 研究テーマをキーコンセプトに分解
2. **シソーラス/MeSH**: 統制語彙の特定
3. **検索式作成**: AND/OR/NOT演算子を使った検索式
4. **データベース別最適化**: PubMed, Scopus, Web of Science向けに調整
5. **検索フィルター**: 年代、言語、文献種別のフィルター提案

$ARGUMENTS を研究テーマとして使用してください。`,
        },
        {
          label: "出力フォーマット",
          content: `- コンセプトマップ（表形式）
- データベース別検索式（コピペ可能）
- 推奨フィルター設定
- 検索戦略の文書化テンプレート`,
        },
      ],
    ),
    agent: agentContent(
      "search-strategy-agent",
      "学術検索戦略を自律的に策定するエージェント",
      [
        {
          label: "役割・専門性",
          content: "学術情報検索戦略の策定を専門とするエージェントです。",
        },
        {
          label: "行動指針",
          content: `1. 研究テーマを分析してキーコンセプトを抽出
2. 各データベース向けの検索式を生成
3. 検索戦略ファイルを作成して保存
4. 検索結果の評価基準を提案`,
        },
        {
          label: "制約事項",
          content: `- 検索式は実際に使用可能な構文にしてください
- 各データベースの構文の違いを正確に反映してください`,
        },
      ],
    ),
    plugin: pluginContent(
      "search-strategy",
      "学術検索戦略を包括的に支援するプラグインパッケージ",
      [
        {
          label: "スキル本文",
          content:
            "PubMed, Scopus, Web of Science等の主要学術データベース向けに最適化された検索式と検索戦略を生成します。",
        },
        {
          label: "エージェント本文",
          content:
            "研究テーマを分析し、複数の学術データベース向けの検索戦略を自律的に策定するエージェントです。",
        },
        {
          label: "CLAUDE.md ガイド",
          content: `## 検索戦略プロジェクト

### ワークフロー
1. /search-strategy で検索戦略を生成
2. データベース別に検索式を調整
3. 検索結果の評価と戦略の改善`,
        },
      ],
    ),
  },

  custom: {
    skill: skillContent("my-skill", "カスタムスキルの説明を入力してください", [
      {
        label: "役割設定",
        content: "あなたの役割を記述してください。",
      },
      {
        label: "タスク指示",
        content: "実行するタスクの指示を記述してください。\n\n$ARGUMENTS を入力として使用できます。",
      },
      {
        label: "出力フォーマット",
        content: "期待する出力形式を記述してください。",
      },
    ]),
    agent: agentContent("my-agent", "カスタムエージェントの説明を入力してください", [
      {
        label: "役割・専門性",
        content: "エージェントの役割と専門性を記述してください。",
      },
      {
        label: "行動指針",
        content: "エージェントの行動手順を記述してください。",
      },
      {
        label: "制約事項",
        content: "エージェントの制約事項を記述してください。",
      },
    ]),
    plugin: pluginContent("my-plugin", "カスタムプラグインの説明を入力してください", [
      {
        label: "スキル本文",
        content: "スキルの指示内容を記述してください。",
      },
      {
        label: "エージェント本文",
        content: "エージェントのシステムプロンプトを記述してください。",
      },
      {
        label: "CLAUDE.md ガイド",
        content: "プロジェクトガイドを記述してください。",
      },
    ]),
  },
};
