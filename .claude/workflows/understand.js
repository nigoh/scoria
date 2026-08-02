export const meta = {
  name: 'understand',
  description: '質問に対して対象領域ごとの並列調査を行い、統合された回答を返す',
  whenToUse: '領域横断の調査質問に、根拠付きで網羅的に答えたいとき（明示要求時のみ）',
  phases: [
    { title: 'Survey', detail: '対象ごとに並列で読み込み調査' },
    { title: 'Synthesize', detail: '調査結果を統合して回答を生成' },
  ],
}

// args は文字列で届く環境があるため防御的にパースする
function parseArgs(raw) {
  let a = raw
  if (typeof a === 'string') {
    try { a = JSON.parse(a) } catch { a = { question: a } }
  }
  if (!a || typeof a !== 'object') a = {}
  return {
    question: a.question || '（質問未指定: リポジトリの全体像を説明する）',
    targets: Array.isArray(a.targets) && a.targets.length > 0 ? a.targets : ['.'],
  }
}

const SURVEY_SCHEMA = {
  type: 'object',
  properties: {
    target: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          claim: { type: 'string', description: '発見した事実' },
          evidence: { type: 'string', description: '根拠となる file:line' },
        },
        required: ['claim', 'evidence'],
      },
    },
    unknowns: { type: 'array', items: { type: 'string' } },
  },
  required: ['target', 'findings'],
}

const { question, targets } = parseArgs(args)

phase('Survey')
log(`調査対象 ${targets.length} 領域: ${targets.join(', ')}`)
const surveys = (await parallel(targets.map(t => () =>
  agent(
    `対象「${t}」を読み込み、次の質問に関係する事実を根拠（file:line）付きで収集せよ。\n` +
    `質問: ${question}\n` +
    `推測は unknowns に分離し、findings には確認できた事実だけを入れること。`,
    { label: `survey:${t}`, phase: 'Survey', schema: SURVEY_SCHEMA }
  )
))).filter(Boolean)

phase('Synthesize')
const answer = await agent(
  `次の調査結果を統合し、質問に対する回答を日本語で作成せよ。\n` +
  `質問: ${question}\n` +
  `調査結果(JSON): ${JSON.stringify(surveys)}\n` +
  `回答は結論を先に、根拠の file:line を添え、調査で確認できなかった点は「不明」と明示すること。`,
  { label: 'synthesize', phase: 'Synthesize' }
)

return { question, targets, answer, surveys }
