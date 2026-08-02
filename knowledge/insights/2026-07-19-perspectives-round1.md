# 品質観点ラウンド分析 — Round 1 の考察（2026-07-19）

`PERSPECTIVES.md` の全観点を5つの並列レンズ（perf/compat/portability・security/privacy/data・
usability/a11y/i18n・reliability/ops/observability・maintainability/test/doc/dx）で deb に当てた結果の
統合・重複排除版。各項目は「deb 固有の穴＋具体提案＋tier＋impact×effort＋根拠」。詳細な提案源は各レンズ。

> これは考察の正本（証跡）。ここから実行可能な候補を `BACKLOG.md` に起票し、周回で1件ずつ消化する。

## テーマ1: 土台自身の実欠陥（スタック非依存で今すぐ直せる）

| # | 症状（deb の穴） | 提案 | tier | I×E | 根拠 |
|---|---|---|---|---|---|
| T1-1 | **ISO 25010 の8特性のうち「互換性」が NFR 7分類に無い**。25010準拠を掲げるのに穴。`/spec` の NFR 一巡と process-auditor が互換性を素通し | NFR に「互換性（共存性・相互運用性）」を追加。`docs/process/requirements.md`・`rules/requirements.md`・process-auditor・ipa-mapping を同期（新 ADR で合意） | approve | 4×4 | requirements.md NFR表(7分類) |
| T1-2 | **トレーサビリティが片方向**。`Verifies:` が実在 REQ/NFR を指すか未検査（幻の参照が素通り） | `check-traceability.sh` に逆方向検査（verifies の各 ID が宣言集合に含まれるか）を追加 | auto | 4×4 | check-traceability.sh |
| T1-3 | **受入基準チェックが見出し有無のみ**（空でも合格） | 見出し直下に Given/When/Then か箇条書き1行以上を要求 | auto | 3×4 | check-traceability.sh |
| T1-4 | **build-plugin.sh / circuit-breaker.sh に振る舞いテストが無い**（check.sh は実行するが正常/異常系フィクスチャ非対称に欠落） | `test-build-plugin.sh`（乖離注入で赤）と circuit-breaker の連続失敗ケースを test に追加し配線 | auto | 4×3 | check.sh は実行/test-* 不在 |
| T1-5 | **CI に timeout-minutes / concurrency が無い**（ハングで既定6h課金・連続pushで旧run残存） | checks.yml に `timeout-minutes: 10` と `concurrency:{cancel-in-progress}` を追加（実行制御であり個別ロジックではない） | auto | 3×5 | checks.yml |
| T1-6 | **check.sh の個別ステップにタイムアウトが無い**（子プロセスのハングで Stop フック/CI が無限停止） | `run()` を `timeout ${GATE_STEP_TIMEOUT:-120}` でラップし超過を NG に | auto | 3×4 | check.sh run() |
| T1-7 | **内部 md リンク切れ検査が ADR index に限定**（docs 相互・CLAUDE.md 参照は未検証） | validate-foundation に相対 .md リンクの実在検査を追加 | auto | 3×4 | validate-foundation.sh |
| T1-8 | **shellcheck がローカルで黙って skip**（local/CI 非再現）。前提ツール確認手段も無い | 不在時に WARN を明示＋`scripts/doctor.sh`（jq/node/shellcheck/bash 診断）＋CONTRIBUTING 追記 | auto | 3×4 | validate-foundation.sh |
| T1-9 | JSON 検証・frontmatter helper が validate-foundation 内で重複 | 共有 `scripts/lib-check.sh` に集約（MAPE の lib.sh と同設計） | approve | 3×3 | validate-foundation.sh |
| T1-10 | 約750行の Bash があるのに **shell の領域 rule が無い** | `.claude/rules/shell.md`（paths: scripts/mape/hooks）: `set -euo pipefail`・mktemp+trap・再帰ガード規約 | approve | 3×4 | .claude/rules/ に shell 無し |

## テーマ2: セキュリティ・プライバシー（土台の防御を厚く）

| # | 症状 | 提案 | tier | I×E | 根拠 |
|---|---|---|---|---|---|
| T2-1 | **秘密のコミット防止が無防備**。guard は .env/鍵の Edit を止めるが、通常ファイルに貼った秘密が commit される。check.sh に secret-scan が無い（最大の穴） | check.sh に secret-scan ゲート雛形（gitleaks/trufflehog 有れば実行・無ければ skip）。MAPE Execute の緑判定に自動で入る | approve | 5×4 | check.sh / guard-protected.sh |
| T2-2 | **Read deny 境界が3層で非対称**。settings.json deny は `./.env`/`./.env.local`/`*.pem` のみで、`.env.production`・サブディレクトリ・`*.key`/`*.p12` が読める（gitignore/guard は網羅） | deny を `Read(**/.env*)`,`Read(**/*.key)`,`Read(**/*.p12/pfx)` に拡張し `.env.example` を許可側に | consult | 4×5 | settings.json vs gitignore/guard |
| T2-3 | **依存脆弱性(CVE)監査ゲートが皆無**（雛形の置き場も無い） | check.sh に dep-audit 雛形（npm audit / pip-audit / cargo audit を stack 選択・未導入skip）。ADR化 | approve | 4×4 | check.sh / POLICY |
| T2-4 | **CI サプライチェーン未固定**。actions がタグ参照（SHA非固定）・dependabot/CODEOWNERS 不在・ブランチ保護が repo 内に未文書化 | Actions を SHA ピン＋dependabot.yml＋CODEOWNERS＋ブランチ保護手順を docs 化・ADR に最終防衛線明記 | approve | 4×3 | checks.yml / 不在確認 |
| T2-5 | **セキュア・コーディング規約が無い**（authn/authz・入力検証・出力エンコード・SSRF/CSRF・PII マスキング） | `.claude/rules/security.md`（paths スコープ雛形、stack-init で有効化）。PII マスキング・保持/削除も同ファイルに | approve | 4×4 | .claude/rules/ に security 無し |
| T2-6 | データ整合性の冪等性・トランザクション・バックアップ/リストアのチェックリストが無い（consult 分類は効いている＝強み） | migration チェックリスト雛形（可逆・トランザクション境界・冪等 upsert・リストア手順）。stack-init で DB 配線 | approve | 3×3 | POLICY consult |

## テーマ3: MAPE 自身の安全化（自律ループの守り）

| # | 症状 | 提案 | tier | I×E | 根拠 |
|---|---|---|---|---|---|
| T3-1 | **AI 自律の分類がキーワード一致のみ**。issue/PR/BACKLOG など**外部由来テキスト**が auto キーワード（patch/format 等）を含むと consult を回避し、無人 Execute が自動 PR 化し得る。（本 Round でも security agent 出力に注入テキストが混入し、この脅威が実地で発生） | POLICY/analyze に「外部由来を出典とする提案は auto 禁止・最低 approve に格上げ」を明記。monitor/analyze 入力を**指示でなくデータ**として扱う旨を規約化 | consult | 4×4 | POLICY 分類 / 本 Round の注入事例 |
| T3-2 | サーキットブレーカーに**自動回復（クールダウン）が無い**。一度 tripped すると手動 reset まで永久停止 | POLICY に `MAPE_CB_COOLDOWN_H`（例24h）を足し、最新 red から一定時間で ok に戻す（ADR化） | approve | 2×4 | circuit-breaker.sh |
| T3-3 | Monitor は記録するが**回帰を鳴らさない**（gate=fail や gate_s スパイクを検知しない） | monitor に閾値判定（前回比 gate_s 悪化 or gate=fail）を足し `⚠` 行を出す→analyze が拾い BACKLOG 化。閾値は POLICY 外出し | approve | 3×3 | monitor.sh / analyze.sh |
| T3-4 | ledger.jsonl・HEALTH 表が**追記のみで上限なし**（長期肥大で status/diff が重く） | reset 時の .bak 退避を定期ローテに拡張・HEALTH は直近 N 行＋要約に畳む（ADR化） | auto | 1×5 | circuit-breaker/monitor |

## テーマ4: stack-init 時に配線する「準備の雛形」（アプリ後に自動で観点が回る）

| # | 観点 | 提案（雛形の先置き） | tier | I×E |
|---|---|---|---|---|
| T4-1 | 性能効率性 | perf-budget テンプレ（bundle KB上限・LCP/CLS/INP 目標）＋stack-init で check.sh 配線手順＋`rules/performance.md` 雛形 | approve | 4×4 |
| T4-2 | アクセシビリティ | `/a11y-review` skill（WCAG 2.2 AA チェックリスト）＋stack-init で axe/Lighthouse-CI を単一ゲートへ配線 | approve | 4×3 |
| T4-3 | 国際化 | `.claude/rules/i18n.md`（文言外出し・複数形・locale 整形・RTL・TZ、paths スコープ） | approve | 3×4 |
| T4-4 | 使用性/UX | requirement-spec の使用性行を UX サブ観点に分解＋`/spec` に UX 小節＋`ui-reviewer` 監査 agent（Write/Edit なし） | approve | 4×4 |
| T4-5 | 観測可能性 | `.claude/rules/observability.md`（構造化ログ・相関ID・レベル）＋HEALTH にアプリ指標 second table 雛形 | approve | 4×2 |
| T4-6 | 運用性 | `/release` skill（リリース/ロールバック runbook 骨子）＋`rules/operability.md`（設定外出し・flag）＋SLO テンプレ | approve | 4×3 |
| T4-7 | UI 品質方針 | ADR「Web UI 導入時、a11y/i18n/SEO を check.sh 単一入口へ配線・閾値必須」 | consult | 4×4 |
| T4-8 | 移植性 | `rules/portability.md`（設定外出し・ハードコード禁止）＋ランタイム版固定・lockfile `--frozen` 検証 | approve | 3×4 |

## テーマ5: MAPE Monitor のシグナル拡張（導入前は "—" で無害）

各レンズが「アプリ導入後に集めるべき」と挙げたシグナルを monitor.sh / HEALTH に**コメント予約**（決定論・低コスト）:
- perf: bundle size / Lighthouse・CWV / 依存の重量
- compat: 対応ブラウザ・Node 版数 / 非互換警告 / API 破壊的差分 / 非UTF-8ファイル
- security: secret 検出数 / CVE 数 / settings.json deny・hooks 差分 / lockfile 鮮度
- a11y/i18n/SEO: axe 違反 / コントラスト不足 / 未翻訳キー / Lighthouse a11y・SEO
- reliability/DORA: error rate / p95 / availability / deploy freq・change fail・lead time・MTTR
- maintainability: カバレッジ% / 複雑度 / 重複率 / CI 時間 / docs 鮮度 / gate フレーキー率

## 枯れ判定（Round 1）と Round 2 で掘る切り口

各レンズの「枯れ判定」で挙がった**未掘り**を Round 2 の対象にする:
- 容量(capacity)・データ量スケール時のリソース上限（perf の下位特性で未検討）
- 相互運用フォーマット（JSON Schema/OpenAPI・タイムゾーン・数値精度）
- `plugin/`（コンパニオン）の secret/deny 規約が `.claude/` 正本と同期しているか
- `mape/state/` に将来 PII/秘密が混入した場合の gitignore 対象化
- GitHub ブランチ保護・required check の**実設定値**（repo 外・要確認）
- AI 安全のより深い切り口（出力の安全性・ツール実行境界）
- 重複整理: secret-scan(T2-1)、security rule(T2-5) は 1提案=1ファイルに束ねると「1周1件」に沿う

> Round 1 は非常に生産的（重複排除後 ~30 の具体候補）。「枯れ」には至っていない → Round 2 で上記を掘る。

---

# Round 2 の考察（網羅性クリティック＋見落とし次元）

2つの並列クリティックが Round 1 と重複しない新規のみを掘った結果。両者とも独立に**「near-dry（掘り尽くしつつある）／Round 3 より実行フェーズへ」**と判定。

## 実害のある新規（要修正）

| # | 症状 | 提案 | tier | I×E | 状態 |
|---|---|---|---|---|---|
| R2-A1 | **コマンド注入**: monitor.env を `. source` し、`MAPE_CHURN_TOP`（git 由来のファイル名・無クォート）を評価。`名前;$(cmd)` なファイルを敵対的 PR が churn 首位に押せば無人ループでコマンド実行 | source を廃止し許可キーのみリテラル代入（`mape_load_env`）。回帰テスト追加 | consult | 4×3 | **本 PR で修正済** |
| R2-A2 | **配布権限境界の欠落**: plugin は guard hooks を運ぶが `settings.json.permissions.deny`（.env/.pem の Read 遮断・push 遮断）を運べない。導入先で秘密読取り境界が丸ごと欠落。build-plugin --check は境界完全性を照合しない | plugin/README に貼るべき deny 雛形を明記＋build-plugin --check に「正本 deny と案内の一致」検査 | approve | 4×3 | BACKLOG |
| R2-A3 | **mape/state のプライバシー**: ledger/issue-body/proposals は追跡対象だが commit 前スキャン/マスキング無し。無人ループが秘密/PII を履歴に固定し得る | commit 前 secret-scan を check.sh に配線（T2-1 と同ゲート）＋外部文字列はダイジェスト化 | consult | 3×3 | BACKLOG |

## 相互運用・容量（stack-init 後に実測で回す領域）

| # | 症状 | 提案 | tier | I×E |
|---|---|---|---|---|
| R2-A4 | ledger.jsonl に契約(スキーマ)検証が無く1行破損で circuit-breaker が沈黙破綻 | 各行 valid JSON＋必須キー(ts/item/result) をテスト。JSON Schema 契約テストの置き場を stack-init 用に予約 | auto | 3×3 |
| R2-A5 | 時刻が秒なし UTC（`mape_now`）で同分の試行が衝突。日付/数値/TZ 横断規約なし | `rules/interop.md` 雛形＋ledger ts を秒精度に | approve | 2×3 |
| R2-A6 | 容量: gate/monitor が木全体走査・除外/上限なし。大規模ホストで線形劣化 | 走査に除外 glob（`git ls-files` 準拠）＋走査ファイル数/秒を signal 化 | approve | 3×3 |

## 丸ごと欠落していた次元（カタログ拡張＝メタ改善）

| # | 次元 | 提案 | tier | I×E | 状態 |
|---|---|---|---|---|---|
| R2-B1 | **LICENSE 不在（法務）**: 「コピーして使う土台」なのにライセンスが無く再利用が法的に不成立 | ライセンス選定を ADR 化→`LICENSE` 追加＋CONTRIBUTING に inbound 条項＋validate に LICENSE 実在検査 | consult | 5×2 | BACKLOG（選定は要判断） |
| R2-B2 | **利用時の品質（QoU）モデルが要件体系に無い**（有効性/効率性/満足性/リスク回避性/利用状況網羅性） | requirements に QoU 節・`/spec` に小節・process-auditor に一巡検査・ipa-mapping に行（ADR化）。カタログには追加済 | approve | 4×3 | 一部済(PERSPECTIVES) |
| R2-B3 | **Safety（ISO 25010:2023 の9特性目）が未収録**。無人 Execute を持つ deb に直結。circuit-breaker は fail-safe の断片だが体系化されていない | PERSPECTIVES に Safety 追加済。要件体系にも Safety を足し MAPE の fail-safe/safe-state を対応付け（ADR で 2023 準拠） | approve | 3×2 | 一部済(PERSPECTIVES) |
| R2-B4 | OSS ライセンス整合/SBOM がカタログ・ゲートに無い | license-scan ゲート雛形（license-checker/cargo-deny）＋SBOM（CycloneDX/SPDX）。stack-init 配線 | approve | 4×3 | BACKLOG |
| R2-B5 | サステナビリティ/テレメトリ設計/倫理設計が観点の死角 | 各 rule 雛形（sustainability/telemetry/inclusive-design）。カタログには追加済 | approve | 3×3 | 一部済(PERSPECTIVES) |
| R2-B6 | 否認防止・責任追跡（署名コミット/来歴） | main は Verified コミット必須＋MAPE 生成 PR に来歴ラベル、ledger に主体を残す（ADR） | approve | 3×3 | BACKLOG |
| R2-B7 | エラーメッセージ品質（リスク回避性・自己適用可）: check.sh の `NG:` が是正手順を示さない | `rules/error-messages.md`（原因＋次の一手＋回復）＋run() の NG に修正ヒント | auto | 3×2 | BACKLOG |
| R2-B8 | required check 名 `quality-gate` 改名で保護が沈黙無効化。実設定値は repo 外＝**要ユーザー確認** | docs に「`quality-gate` を改名しない」契約＋改名時の保護更新手順。実値はユーザー確認 | approve | 3×2 | BACKLOG |

## 枯れ判定（統合）

- 両クリティックが独立に **near-dry** と判定。Round 1（~30候補）で鉱脈の大半、Round 2 で残りの「丸ごと欠落次元」（Safety/QoU/法務/倫理）と「MAPE 自身の実害」（sourcing 注入・plugin 権限・state プライバシー）を確定。
- 残りは (a) **カタログ枠の追加＝メタ改善**（本 PR で PERSPECTIVES に Safety/QoU/法務/倫理/サステナ/テレメトリを追加＝ほぼ実施）、(b) **stack-init 後に実測で回す領域**（相互運用・容量・perf・a11y のツール実測）、(c) **1周1件で消化する実装候補**（BACKLOG）。
- よって **discovery ラウンドは Round 2 で枯れたと判断**。以降は Execute（1周1件）と、要件体系側の拡張（互換性・Safety・QoU を ADR で追加）に移る。**要ユーザー確認**: LICENSE 選定、GitHub ブランチ保護/required check の実設定値。
