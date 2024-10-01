/**
 * @file Tests the config works as expected based on a sampling of rules.
 */
import { readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { ESLint } from 'eslint'

import { getEslintConfig } from '../eslint.config'

const __dirname = dirname(fileURLToPath(import.meta.url))

describe('eslint.config.cjs', () => {
  const lintTests = [
    [
      'detects non-literal regex',
      'non-literal-regex',
      ['prefer-regex-literals'],
    ],
    [
      'detects missing dangling commas',
      'dangling-commas',
      ['@stylistic/comma-dangle', '@stylistic/comma-dangle'],
    ],
    [
      'detects Windows style newlines',
      'windows-style-newline',
      ['@stylistic/linebreak-style', '@stylistic/linebreak-style'],
    ],
  ]

  test.each(lintTests)('%s', async (description, testDir, ruleIds) => {
    const eslint = new ESLint({
      overrideConfigFile : true,
      overrideConfig     : getEslintConfig(),
    })

    const results = await eslint.lintFiles(
      `src/lib/default-config/test/data/${testDir}/**/*`
    )

    expect(results).toHaveLength(1)
    // do this first so we get info about the failed rules
    const failedRules = results[0].messages.map((m) => m.ruleId)
    expect(failedRules).toEqual(ruleIds)
  })
})
