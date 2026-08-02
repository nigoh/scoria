export const meta = {
  name: 'quality-gates',
  description: 'PR 前の品質ゲートを並列実行する: code-reviewer / doc-auditor / rule-auditor / process-auditor + scripts/check.sh',
  whenToUse: 'PR 作成前に多角的な品質確認を一括で行いたいとき（明示要求時のみ）',
  phases: [
    { title: 'Gates', detail: '監査エージェント4種 + 機械ゲートを並列実行' },
    { title: 'Verify', detail: 'ERROR 指摘を敵対的に検証して確定させる' },
  ],
}

function parseArgs(raw) {
  let a = raw
  if (typeof a === 'string') {
    try { a = JSON.parse(a) } catch { a = { base: a } }
  }
  if (!a || typeof a !== 'object') a = {}
  return { base: a.base || 'main' }
}

const REPORT_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['ERROR', 'WARNING', 'INFO'] },
          kind: { type: 'string' },
          location: { type: 'string', description: 'file:line' },
          detail: { type: 'string' },
        },
        required: ['severity', 'kind', 'location', 'detail'],
      },
    },
    verdict: { type: 'string', enum: ['go', 'no-go'] },
  },
  required: ['findings', 'verdict'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    isReal: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['isReal', 'reason'],
}

const { base } = parseArgs(args)
const diffInstruction =
  `対象は「git diff ${base}...HEAD」の変更範囲（差分が空ならリポジトリ全体）。`

phase('Gates')
const GATES = [
  { key: 'code-review', agentType: 'code-reviewer',
    prompt: `${diffInstruction} 差分をレビューし、指摘を構造化して返せ。` },
  { key: 'doc-audit', agentType: 'doc-auditor',
    prompt: `${diffInstruction} ドキュメント整合性（一覧表同期・ADR index・記述と実体の乖離・リンク）を監査せよ。` },
  { key: 'rule-audit', agentType: 'rule-auditor',
    prompt: `${diffInstruction} 開発規約（ブランチ・Conventional Commits・ADR 要否・steering 配置・品質ゲート）を監査し go/no-go を判定せよ。` },
  { key: 'process-audit', agentType: 'process-auditor',
    prompt: `${diffInstruction} 開発プロセス遵守（段階ゲート・トレーサビリティ完全性・NFR一巡・受入基準・変更管理）を監査し go/no-go を判定せよ。要件成果物が無い変更ならプロセス観点は対象外として go でよい。` },
  { key: 'check-sh', agentType: null,
    prompt: `リポジトリルートで「bash scripts/check.sh」を実行し、結果を報告せよ。失敗があれば各失敗を severity=ERROR の finding にし verdict=no-go、全て緑なら findings は空で verdict=go とする。` },
]
const reports = (await parallel(GATES.map(g => () =>
  agent(g.prompt, {
    label: `gate:${g.key}`,
    phase: 'Gates',
    schema: REPORT_SCHEMA,
    ...(g.agentType ? { agentType: g.agentType } : {}),
  }).then(r => ({ gate: g.key, ...r }))
))).filter(Boolean)

const allFindings = reports.flatMap(r =>
  (r.findings || []).map(f => ({ ...f, gate: r.gate })))
const errors = allFindings.filter(f => f.severity === 'ERROR')
log(`所見 ${allFindings.length} 件（ERROR ${errors.length} 件）`)

phase('Verify')
// ERROR だけ敵対的に検証し、確定 ERROR を作る（WARNING/INFO はそのまま通す）
const verifiedErrors = (await parallel(errors.map(e => () =>
  agent(
    `次の指摘を敵対的に検証せよ。実際のソースを読み、本当に問題か反証を試みること。迷ったら isReal=false。\n` +
    `指摘: ${JSON.stringify(e)}`,
    { label: `verify:${e.gate}`, phase: 'Verify', schema: VERDICT_SCHEMA }
  ).then(v => ({ ...e, verdict: v }))
))).filter(Boolean)

const confirmedErrors = verifiedErrors.filter(e => e.verdict && e.verdict.isReal)
// 総合判定は検証を通過した確定 ERROR の有無で決める
// （gateVerdicts は検証前の各ゲートの自己申告であり、参考情報として返す）
const overall = confirmedErrors.length === 0 ? 'go' : 'no-go'

return {
  base,
  overall,
  confirmedErrors,
  dismissedErrors: verifiedErrors.filter(e => !e.verdict || !e.verdict.isReal).map(e => e.detail),
  warnings: allFindings.filter(f => f.severity !== 'ERROR'),
  gateVerdicts: reports.map(r => ({ gate: r.gate, verdict: r.verdict })),
}
