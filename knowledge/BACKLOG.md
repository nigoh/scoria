# BACKLOG — 作りたいことの候補（優先度順）

MAPE-K の Analyze が追記し、Execute が消化する候補置き場（ADR-0010）。人間も自由に足してよい。
優先度は P1（高）> P2 > P3。`tier` は POLICY.md のリスク分類（auto/approve/consult）。

各項目のフォーマット:
`- [ ] (P?, tier) タイトル — 根拠 / インパクト×労力`

`analyze.sh` は監視シグナルから候補を自動追記し、`plan.sh` はここと分析結果からイシュー本文を生成する。
実装が完了した項目は Execute が `[x]` にして「→ PR #N」を付す。

## 候補

<!-- Analyze が監視シグナルから追記する。人間も自由に足してよい。 -->

- [x] (P1, approve) `src/lib` の無テスト領域（templates / constants / cli / zip）にテストを入れる — 根拠: 現状 generator.ts のみ 15 件 / 高×中 → PR #5（cli の欠陥2件も摘出）
- [x] (P2, approve) stores（wizard / extension / history）の状態遷移テスト — 根拠: 画面をまたぐ状態で回帰が出やすい / 中×中 → PR #5
- [x] (P3, approve) テスト網羅率の定量ゲートを check.sh に追加する — 根拠: 現状は緑/赤のみで穴が見えない / 中×中 → PR #9（src/lib に閾値。ADR-0029）
- [x] (P2, approve) `src/components` `src/features` の UI テストが1本も無い — 根拠: ウィザードの分岐はコンポーネント側にある。jsdom 導入の要否から判断する / 中×大 → PR #9（jsdom 導入・GraphView / WizardProgress）
- [ ] (P3, auto) `mape/monitor.sh` にアプリ側の指標（テスト件数）を追記する — 根拠: HEALTH がまだ土台側の指標しか見ていない / 小×小

## アーカイブ

<!-- 未チェックのまま一定期間過ぎた計画項目や、却下された項目をここへ移す（計画イシューを腐らせない）。 -->
