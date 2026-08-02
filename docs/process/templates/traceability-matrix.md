<!-- トレーサビリティ表の雛形。要件→設計→実装→テストの全体俯瞰（docs/process/traceability.md） -->
# トレーサビリティ表

| 要件 ID | 要件（要約） | 優先度 | 設計 (DES/ADR) | 実装（場所） | テスト (Verifies) | 状態 |
|---|---|---|---|---|---|---|
| REQ-<領域>-001 | | 高 | DES-001 | src/... | TEST-unit-001, TEST-acceptance-001 | 実装済 |
| NFR-SEC-001 | | 高 | ADR-00NN | | TEST-system-001 | 未着手 |

> `check-traceability.sh` は要件→テストの被覆（`Verifies:`）を機械検証する。この表は人間が全体像を
> 俯瞰するための一覧。要件が増えたら行を足し、状態（未着手/設計済/実装済/検証済）を更新する。
