// Pure-function tests for the runtime's scoring (run: node --test test/js/).
// Importing the runtime outside a browser is safe: start() is a no-op
// without `document`.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { commandScore, commandScoreWithMatches, defaultFilter } from '../../assets/js/cmdk.js'
import { referenceCommandScore } from './reference_command_score.mjs'

// Deterministic pseudo-random strings (fictional vocabulary only).
function rng(seed) {
  let x = seed
  return () => ((x = (x * 1103515245 + 12345) % 2147483648) / 2147483648)
}
const WORDS = ['Northwind', 'Journal', 'almanac', 'lighthouse', 'field-notes', 'Create', 'post', 'Go to',
  'specimens', 'Media', 'Header', 'site_settings', 'A/B', 'v2.1', 'Ünïcode', 'café', 'x', 'aa', 'ab', 'ba']

function sample(random, maxWords) {
  const n = 1 + Math.floor(random() * maxWords)
  return Array.from({ length: n }, () => WORDS[Math.floor(random() * WORDS.length)]).join(random() < 0.5 ? ' ' : '-')
}

function abbreviate(random, string) {
  // Mostly subsequences (matches), sometimes swaps/doubles/noise (edge paths).
  let out = ''
  for (const ch of string) if (random() < 0.3) out += ch
  const r = random()
  if (r < 0.1 && out.length > 1) out = out[1] + out[0] + out.slice(2)
  else if (r < 0.2 && out.length > 0) out = out[0] + out
  else if (r < 0.3) out += 'qz'
  return out.slice(0, 12) || string.slice(0, 1)
}

test('scores are identical to the 0.1.1 implementation', () => {
  const random = rng(42)
  for (let i = 0; i < 5000; i++) {
    const value = sample(random, 5)
    const aliases = random() < 0.3 ? [sample(random, 2)] : undefined
    const query = abbreviate(random, value + ' ' + (aliases || []).join(' '))
    const expected = referenceCommandScore(value, query, aliases)
    assert.equal(commandScore(value, query, aliases), expected, `${value} / ${query}`)
    assert.equal(commandScoreWithMatches(value, query, aliases).score, expected, `${value} / ${query}`)
  }
})

test('known rankings of the cmdk algorithm', () => {
  assert.equal(commandScore('Posts', 'posts'), referenceCommandScore('Posts', 'posts'))
  assert.ok(commandScore('Posts', 'pst') > commandScore('Pages settings', 'pst'))
  assert.equal(commandScore('Media', 'xyz'), 0)
  assert.ok(commandScore('Media', 'image', ['image', 'upload']) > 0)
  assert.equal(defaultFilter('Media', 'med', []), commandScore('Media', 'med', []))
})

test('matches are the matched positions, ascending', () => {
  assert.deepEqual(commandScoreWithMatches('Northwind Journal', 'nj'), {
    score: commandScore('Northwind Journal', 'nj'),
    matches: [0, 10],
  })
  assert.deepEqual(commandScoreWithMatches('Posts', 'pos').matches, [0, 1, 2])
  assert.deepEqual(commandScoreWithMatches('Go to Posts', 'gpo').matches, [0, 6, 7])
})

test('matches prefer word starts like the score does', () => {
  // "lh": the "h" starting the second word beats the earlier "h" of "Light".
  assert.deepEqual(commandScoreWithMatches('Light House', 'lh').matches, [0, 6])
  assert.deepEqual(commandScoreWithMatches('Lighthouse', 'lh').matches, [0, 3])
})

test('no matches when the score is 0', () => {
  assert.deepEqual(commandScoreWithMatches('Media', 'xyz'), { score: 0, matches: [] })
})

test('matches may point into the aliases', () => {
  const { score, matches } = commandScoreWithMatches('Media', 'upl', ['upload'])
  assert.ok(score > 0)
  assert.deepEqual(matches, [6, 7, 8]) // "Media upload"
})

test('a transposition highlights both swapped characters', () => {
  const { score, matches } = commandScoreWithMatches('ab', 'ba')
  assert.equal(score, referenceCommandScore('ab', 'ba'))
  assert.ok(score > 0)
  assert.deepEqual(matches, [0, 1])
})

test('matches stay within the string and are case-insensitive', () => {
  const random = rng(7)
  for (let i = 0; i < 2000; i++) {
    const value = sample(random, 4)
    const query = abbreviate(random, value)
    const { score, matches } = commandScoreWithMatches(value, query)
    if (score === 0) {
      assert.deepEqual(matches, [])
      continue
    }
    assert.ok(matches.length > 0 && matches.length <= query.length, `${value} / ${query}`)
    for (let j = 1; j < matches.length; j++) assert.ok(matches[j] > matches[j - 1])
    for (const m of matches) {
      assert.ok(m >= 0 && m < value.length)
      assert.ok(query.toLowerCase().replace(/[\s-]/g, ' ').includes(value[m].toLowerCase().replace(/[\s-]/g, ' ')), `${value} / ${query} @${m}`)
    }
  }
})
