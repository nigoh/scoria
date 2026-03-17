# Scoria — ロゴガイドライン

## ロゴコンセプト

**F2: Bold Pipe**

「S」をアクセントカラー（セージグリーン）で強調し、太いパイプ記号「|」で区切ることで、
UNIXのパイプ演算子（データの精製・変換・次工程への受け渡し）を暗喩するワードマーク。

- タイプ: ワードマーク（文字のみ）
- モチーフ: パイプ演算子（|）— プロンプト・テキスト処理の象徴
- スタイル: ジオメトリック（直線・幾何学的）
- フォント: Noto Sans JP Bold (700)

## ロゴ構成要素

```
  S  |  coria
  ↑  ↑    ↑
  ①  ②   ③

① 「S」: アクセントカラー（green-500 / green-400）
② パイプ: アクセントカラー、opacity 0.6、幅5px、角丸2.5px
③ 「coria」: テキストカラー（gray-900 / zinc-50）
```

## ファイル一覧

| ファイル | 用途 | 背景 |
|---|---|---|
| `scoria-logo-light.svg` | ライトモード用メインロゴ | 白・明るい背景 |
| `scoria-logo-dark.svg` | ダークモード用メインロゴ | 黒・暗い背景 |
| `scoria-logo-mono-white.svg` | モノクロ白 | 暗い背景・写真上 |
| `scoria-logo-mono-black.svg` | モノクロ黒 | 明るい背景・印刷 |
| `scoria-favicon.svg` | ファビコン / アプリアイコン | 任意 |

## カラー仕様

### ライトモード

| 要素 | カラー | HEX |
|---|---|---|
| S（アクセント） | green-500 | `#22c55e` |
| パイプ | green-500 @ 60% | `#22c55e` opacity 0.6 |
| coria（テキスト） | gray-900 | `#111827` |

### ダークモード

| 要素 | カラー | HEX |
|---|---|---|
| S（アクセント） | green-400 | `#4ade80` |
| パイプ | green-400 @ 60% | `#4ade80` opacity 0.6 |
| coria（テキスト） | zinc-50 | `#fafafa` |

### ファビコン

| 要素 | カラー | HEX |
|---|---|---|
| 背景 | green-500 | `#22c55e` |
| S | white | `#ffffff` |
| パイプ | white @ 50% | `#ffffff` opacity 0.5 |
| 角丸 | 6px | — |

## サイズガイドライン

| 使用箇所 | 最小幅 | 推奨幅 |
|---|---|---|
| ヘッダーナビゲーション | 100px | 120px |
| ヒーローセクション | 200px | 280px |
| フッター | 80px | 100px |
| ファビコン | 16x16px | 32x32px |
| OGP画像内 | — | 240px |

## 禁止事項

- ロゴの色を変更しない（アクセントカラー以外の色に変えない）
- パイプの位置・太さ・不透明度を変更しない
- ロゴを回転・変形・傾斜させない
- ロゴの周囲に十分な余白（最低「S」の高さの50%）を確保する
- 低コントラストの背景にモノクロ版を使わない

## Reactコンポーネント実装例

```tsx
// components/ScoriaLogo.tsx
interface ScoriaLogoProps {
  width?: number;
  theme?: 'light' | 'dark';
}

export function ScoriaLogo({ width = 180, theme = 'light' }: ScoriaLogoProps) {
  const accent = theme === 'dark' ? '#4ade80' : '#22c55e';
  const text = theme === 'dark' ? '#fafafa' : '#111827';

  return (
    <svg viewBox="0 0 360 80" width={width} xmlns="http://www.w3.org/2000/svg">
      <text x="10" y="58" fontFamily="'Noto Sans JP', sans-serif" fontSize="48" fontWeight="700" letterSpacing="-0.5" fill={accent}>S</text>
      <rect x="46" y="12" width="5" height="52" rx="2.5" fill={accent} opacity="0.6"/>
      <text x="64" y="58" fontFamily="'Noto Sans JP', sans-serif" fontSize="48" fontWeight="700" letterSpacing="-0.5" fill={text}>coria</text>
    </svg>
  );
}
```

---

*作成日: 2026-03-17*
*コンセプト: F2 Bold Pipe*
*作成者: Hiromobu / Claude*
