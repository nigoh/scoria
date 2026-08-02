# ADR Index

意思決定記録（Architecture Decision Records）。作成は `/adr` スキルで行う（規約: `.claude/rules/adr.md`）。

> ADR 0001〜0009 はリポジトリ立ち上げ・プロセス醸成・拡張時の founding ADR であり、例外として作成時に Accepted とした。
> 以降の ADR は Proposed で作成し、PR レビューを経て Accepted にする。
>
> **訂正の範囲**: Accepted な ADR も、それを導入した PR が main にマージされるまでは訂正してよい
> （レビュー中の推敲）。**main にマージされた後は編集禁止**で、覆すときは新 ADR で supersede する。
> この境界は `.claude/hooks/guard-protected.sh` が origin/main 上の存在で機械判定する（マージ後は編集ブロック）。

| 番号 | タイトル | Status |
|---|---|---|
| [0001](0001-steering-placement-policy.md) | Claude Code steering の機構配置ポリシー | Accepted |
| [0002](0002-development-workflow.md) | 開発ワークフロー（ラウンド + GitHub Flow + Conventional Commits） | Accepted |
| [0003](0003-stack-agnostic-foundation.md) | 土台はスタック非依存とし、スタック導入は /stack-init で行う | Accepted |
| [0004](0004-quality-gate-enforcement.md) | ルールの3層強制と品質ゲートの単一入口 | Accepted |
| [0005](0005-development-lifecycle-v-model.md) | 開発ライフサイクルとして V字モデル＋段階ゲートを採用 | Accepted |
| [0006](0006-requirements-and-traceability.md) | 要件管理とトレーサビリティを ID 体系で徹底する | Accepted |
| [0007](0007-prevention-and-detection-quality.md) | 品質は「予防活動」と「検知活動」の二本立てで作り込む | Accepted |
| [0008](0008-companion-plugin.md) | 移植可能サブセットを deb 内のコンパニオンプラグインとして提供する | Accepted |
| [0009](0009-upstream-feedback-loop.md) | テンプレート由来リポジトリから本家へのフィードバックループ | Accepted |
| [0010](0010-mape-k-nighttime-self-improvement.md) | MAPE-K 型の夜間セルフ改善システム | Accepted |
| [0011](0011-mape-k-autonomy-and-lean-board.md) | MAPE-K の自律運用（夜間スケジュール・自動 Execute）と計画イシューのスリム化 | Proposed |
| [0012](0012-repository-license.md) | リポジトリのライセンスを MIT とする | Proposed |
| [0013](0013-test-first-and-testing-rigor.md) | テスト厳格度ポリシー（test-first を含む）を重要度×規模で校正する | Proposed |
| [0014](0014-mape-k-living-autonomic-cell.md) | MAPE-K を「生きた自律細胞」へ（恒常性・効き目・膜・自己修復・安全状態） | Proposed |
| [0015](0015-mape-k-item-quarantine-and-bounded-breaker-recovery.md) | MAPE-K の項目隔離と有界なブレーカー自己修復 | Proposed |
| [0016](0016-mape-k-safe-state-model.md) | MAPE-K の安全状態（safe-state）モデル | Proposed |
| [0017](0017-mape-k-efficacy-feedback-self-optimization.md) | MAPE-K の効き目フィードバック（self-optimization） | Proposed |
| [0018](0018-consolidate-mape-command-and-quiet-bundled-skills.md) | MAPE-K スキルを単一 `/mape` に統合し `/` コマンド面を絞る | Proposed |
| [0019](0019-mape-k-nightly-self-run.md) | MAPE-K の夜間自走（heartbeat）— GHA cron で決定論 M→A→P | Superseded by [0023](0023-stop-mape-nightly-cron.md) |
| [0020](0020-github-pages-landing-site.md) | リポジトリ紹介の GitHub Pages ランディングを追加する（ブランチ配信・root） | Proposed |
| [0021](0021-source-reference-generation-with-shdoc.md) | ソースリファレンスを shdoc で自動生成し、3層のドキュメントサイトとして公開する | Proposed |
| [0022](0022-pyramid-principle-as-a-machine-checked-doc-contract.md) | ドキュメント構成をピラミッド原則で統一し、構造マーカーで機械検査する | Proposed |
| [0023](0023-stop-mape-nightly-cron.md) | MAPE-K の夜間 cron を止め、手動起動のみにする（0019 を supersede） | Proposed |
| [0024](0024-adopt-deb-foundation-and-stack-gates.md) | deb の開発土台を移植し、Vite + React スタックを品質ゲートに配線する | Accepted |
| [0025](0025-exclude-companion-plugin-and-retarget-doc-gates.md) | コンパニオンプラグインを移植対象から外し、ドキュメント系ゲートを Scoria 向けに向け直す | Accepted |
