# POLICY — 好み・重点テーマ・リスク分類・自律レベル

MAPE-K の Analyze / Plan が**提案の前に必ず読む**規範（ADR-0010）。人間がここを編集して好みを教える。

## 今月の重点テーマ

<!-- A はこのテーマに合う提案を優先的に上位へ。空なら重み付けなし。 -->

- `src/lib` の生成ロジックにテストの安全網を張る（templates / constants / cli / zip が未検証）
- ドキュメントとコードの乖離をなくす（一覧同期・ADR index）

## 好み（Preferences）

- 小さく可逆な変更を好む。1周1件。大きなリファクタは分割して提案する。
- 日本語で書く。既存コードの語彙・コメント密度に合わせる。
- 決定は ADR に残す。品質ゲートは `scripts/check.sh` に足す（フックや CI に直書きしない）。

## 自律レベル（Autonomy）

<!-- mape/plan.sh はこの表の tier をリスク分類の既定に使う。 -->

| tier | 意味 | Execute の扱い |
|---|---|---|
| auto | 無害・可逆（整形・テスト追加・ドキュメント同期・パッチ更新） | チェック不要で実装（PR まで。マージはしない） |
| approve | 挙動が変わる（新機能・リファクタ・依存 minor/major） | 人間がチェックした項目だけ実装 |
| consult | 認証・課金・データ・秘密・デプロイに触れる | チェックされても即実装せず、まず質問する |

### 運用モード（ADR-0011。現在の設定）

- **M→A→P**: **手動で1周**（読み取り専用・安全）。ラウンド開始時などに `/mape night` か
  Actions の `mape-nightly` を手で起動する。計画イシューは「1本の板＋完了を畳む」でスリムに保つ。
  夜間 cron は ADR-0023 で停止した（毎晩回しても新しい情報は gate_s の数値だけで、解決済み提案の
  残留とブランチ蓄積の損が上回ったため）。
- **Execute**: M→A→P の後に、**対話セッションの `/mape execute` で**実行する。**auto と 人がチェックした
  approve のみ・1周1件・PR まで**。consult は無人実行では扱わない（有人で判断）。**マージは常に人間**。
  サーキットブレーカーで暴走を止める。
- 自動運用へ戻したいときは、この節を書き換え、`mape-nightly.yml` に `schedule:` を戻して新 ADR を書く。

### 健全性バンド（setpoints）

<!-- mape/analyze.sh が下の block を読み、指標が warn/crit を超えたら逸脱幅に応じた提案を出す（恒常性。
     ADR-0014）。形式は `metric  warn  crit`（direction は lower＝小さいほど良い前提。1行1指標）。
     ここを編集すれば反応閾値をコードでなく POLICY で調律できる。block/指標が無ければ analyze の
     baked-in 既定にフォールバックする。見出し・fence はリネームしない（mape/lib.sh mape_setpoints が読む）。 -->

```
gate_s     15  30
todo        1  10
claude_md 190 200
max_skill 450 500
```

## リスク分類ルール（キーワード）

<!-- mape/analyze.sh / mape/plan.sh が下のコードブロック内の行を読み、提案文にマッチしたら分類する。
     判定は consult > approve > auto の順（危険側優先）。auto にマッチせず consult/approve にも
     マッチしなければ既定は approve（安全側）。1行1キーワード。 -->

### consult（相談：触れたら止めて質問）

```
auth
認証
ログイン
password
secret
秘密
credential
課金
billing
payment
決済
本番
production
deploy
デプロイ
migration
マイグレーション
個人情報
personal data
.env
```

### approve（承認：挙動が変わる）

```
リファクタ
refactor
新機能
feature
挙動
behavior
API 変更
breaking
依存更新
minor
major
```

### auto（自動：無害・可逆）

```
テスト追加
add test
テストを書く
整形
format
フォーマット
lint
typo
誤字
ドキュメント同期
doc sync
コメント
TODO 解消
resolve todo
パッチ
patch
```

## 却下ログ（Rejected）

<!-- 人間が却下した提案を「- pattern: <正規表現> — <理由>」の形で残す。
     A は提案前にここを読み、pattern にマッチする案を出さない（好みに寄っていく）。-->

- pattern: 大規模な全面書き換え — 1周1件・小さく可逆の原則に反する
