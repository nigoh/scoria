# HEALTH — 健全性指標のベースラインと推移

Monitor（`mape/monitor.sh`）が**毎周回1行**を「指標の推移」の表に追記する（ADR-0010）。
「N 周で TODO 12→3」のように、実際に良くなっているかを定量で示すための記録。

指標は品質ゲートの合否と所要秒（テスト時間相当）、TODO/FIXME 数、予算に対する行数、ADR 数。
アプリ側の指標（テスト件数・網羅率）は `mape/monitor.sh` に追記して育てる（ADR-0024）。

## 指標の定義

| 指標 | 意味 | 良い方向 |
|---|---|---|
| gate | `scripts/check.sh` の合否（pass/fail） | pass |
| gate_s | check.sh 所要秒（テスト時間相当） | 小 |
| todo | TODO/FIXME コメント数 | 小 |
| scripts | Bash スクリプト数（`.sh`） | 参考値 |
| max_skill | 最長 SKILL.md の行数（予算 500） | 500 未満 |
| claude_md | CLAUDE.md 行数（予算 200） | 200 未満 |
| adr | ADR 件数 | 参考値 |

## 指標の推移

<!-- mape/monitor.sh が下の表に1行/周回で追記する。列順は固定（監視スクリプトが依存）。
     ヘッダ行と区切り行はリネーム・削除しない。 -->

| ts(UTC) | cycle | gate | gate_s | todo | scripts | max_skill | claude_md | adr | note |
|---|---|---|---|---|---|---|---|---|---|
