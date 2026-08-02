---
paths:
  - "docs/adr/**"
---

# ADR 規約

- 作成は `/adr` スキルで行う（連番4桁 `NNNN-kebab-case.md`、template.md をコピー）。
- Status は `Proposed` で作成し、PR レビューを経て `Accepted` にする。
- **Accepted 済み ADR は編集しない**（hooks でもブロックされる）。決定を覆すときは新しい ADR を作成し、旧 ADR の Status を `Superseded by NNNN` に更新する（Status 行の更新のみ可）。
- 「検討した選択肢」には必ず2つ以上の案を pros/cons 付きで書く。
- 「結果」には決定を再検討するトリガー条件（〜になったら見直す）を明記する。
- 追加したら docs/adr/README.md の index を更新する（validate-foundation.sh が検証する）。
