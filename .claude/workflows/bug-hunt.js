export const meta = {
  name: 'bug-hunt',
  description: '観点別レンズで並列にバグを発見し、敵対的検証を通過した確定バグだけを返す',
  whenToUse: '対象範囲のバグを網羅的に洗い出したいとき（明示要求時のみ）。確定0件まで繰り返して使う',
  phases: [
    { title: 'Find', detail: '観点レンズごとに並列でバグ探索' },
    { title: 'Verify', detail: '各所見を独立の検証者が反証テスト' },
  ],
}

function parseArgs(raw) {
  let a = raw
  if (typeof a === 'string') {
    try { a = JSON.parse(a) } catch { a = { scope: a } }
  }
  if (!a || typeof a !== 'object') a = {}
  return { scope: a.scope || 'リポジトリ全体' }
}

// 観点レンズ: 同じ場所を別の角度から見ることで冗長でない多様性を作る
const LENSES = [
  { key: 'correctness', prompt: 'ロジックの正確性: 境界条件、off-by-one、null/undefined、誤った条件式' },
  { key: 'error-handling', prompt: 'エラー処理: サイレント失敗、握りつぶされた例外、失敗時の不整合な状態' },
  { key: 'state-lifecycle', prompt: '状態とライフサイクル: 初期化漏れ、リソースリーク、競合状態、順序依存' },
  { key: 'config-env', prompt: '設定と環境: パス・環境変数の仮定、移植性、権限、フェイルオープンの穴' },
  { key: 'docs-drift', prompt: 'ドキュメントとの乖離: 書かれた仕様・規約と実装の食い違い' },
]

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'number' },
          kind: { type: 'string', enum: ['bug', 'smell', 'question'] },
          detail: { type: 'string', description: '再現条件と誤動作の具体的説明' },
        },
        required: ['title', 'file', 'kind', 'detail'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    isReal: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['isReal', 'reason'],
}

const { scope } = parseArgs(args)

phase('Find')
log(`対象: ${scope} / レンズ ${LENSES.length} 本で並列探索`)
const found = (await parallel(LENSES.map(l => () =>
  agent(
    `対象「${scope}」を「${l.prompt}」の観点だけで精査し、バグ候補を挙げよ。\n` +
    `根拠の file:line と、具体的な再現条件・誤動作を必ず書くこと。確信が持てないものは kind=question にする。`,
    { label: `find:${l.key}`, phase: 'Find', schema: FINDINGS_SCHEMA, effort: 'high' }
  )
))).filter(Boolean).flatMap(r => r.findings || [])

// file+line+title で重複排除
const seen = new Set()
const unique = found.filter(f => {
  const k = `${f.file}::${f.line ?? '?'}::${f.title}`
  if (seen.has(k)) return false
  seen.add(k)
  return true
})
const bugs = unique.filter(f => f.kind === 'bug')
log(`所見 ${found.length} 件 → 重複排除後 ${unique.length} 件（うち bug ${bugs.length} 件）`)

phase('Verify')
const verified = (await parallel(bugs.map(b => () =>
  agent(
    `次のバグ報告を敵対的に検証せよ。実際のソースを読み、本当に発生するか反証を試みること。\n` +
    `迷ったら isReal=false にする（偽陽性を通すより見逃す方がよい）。\n` +
    `報告: ${JSON.stringify(b)}`,
    { label: `verify:${b.file}:${b.line ?? '?'}`, phase: 'Verify', schema: VERDICT_SCHEMA }
  ).then(v => ({ ...b, verdict: v }))
))).filter(Boolean)

const confirmed = verified.filter(b => b.verdict && b.verdict.isReal)
const rejected = verified.filter(b => !b.verdict || !b.verdict.isReal)
const rest = unique.filter(f => f.kind !== 'bug')

return {
  scope,
  confirmed,
  rejectedCount: rejected.length,
  rejectedTitles: rejected.map(b => b.title),
  rest,
}
