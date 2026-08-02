# tools/shdoc — vendoring した shdoc

シェルスクリプトのコメント（`# @description` 等）から Markdown の API ドキュメントを生成するツール。
`scripts/build-docs.sh` がこれを呼び、`reference.html` を生成する。

## 出所

| 項目 | 値 |
|---|---|
| 上流 | https://github.com/reconquest/shdoc |
| 取得元（本体） | https://raw.githubusercontent.com/reconquest/shdoc/master/shdoc |
| 取得元（LICENSE） | https://raw.githubusercontent.com/reconquest/shdoc/master/LICENSE |
| 取得日 | 2026-07-30 |
| バージョン | 1.4（本体 `shdoc_version = "1.4"`） |
| コミット | `52917b2f3471fe77c745ede115494d2d5c9168d1`（取得時の master HEAD） |
| SHA-256（shdoc） | `856bdc62db15e4970c59f011e9a779d6a23e86f4f123707e25f5390d14c9b191` |
| ライセンス | MIT（Copyright (c) 2017 Stanislav Seletskiy & Egor Kovetskiy。全文は `LICENSE`） |

## 改変

**無改変**（上流のバイト列そのまま）。改変する場合は、ここに差分の要点と理由を必ず書くこと
（上流追従のたびに再適用が必要になるため、改変は最後の手段）。

## 前提

`shdoc` の shebang は `#!/usr/bin/gawk -E` であり、**gawk（GNU awk）が必須**。
`scripts/build-docs.sh` は gawk が無い場合、判定不能を合格に倒さず明示メッセージ付きで失敗する。

- Debian/Ubuntu: `apt-get install -y gawk`
- macOS: `brew install gawk`
- CI: ワークフローに gawk のインストールを入れること

## 更新手順

1. 差し替える。

   ```bash
   curl -sSL -o tools/shdoc/shdoc   https://raw.githubusercontent.com/reconquest/shdoc/master/shdoc
   curl -sSL -o tools/shdoc/LICENSE https://raw.githubusercontent.com/reconquest/shdoc/master/LICENSE
   chmod +x tools/shdoc/shdoc
   ```

2. 上の表（取得日・バージョン・コミット・SHA-256）を更新する。
   コミットは `git ls-remote https://github.com/reconquest/shdoc.git HEAD`、
   SHA-256 は `sha256sum tools/shdoc/shdoc` で得る。
3. `bash scripts/test-build-docs.sh` と `bash scripts/build-docs.sh` を実行し、
   生成物の差分（`reference.html`）をレビューしてからコミットする。
4. 上流の挙動が変わった場合は `scripts/build-docs.sh` の Markdown→HTML 変換側（MD2HTML）も追随させる。
