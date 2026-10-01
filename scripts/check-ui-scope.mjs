import { execFileSync } from 'node:child_process'

const baseSha = process.env.BASE_SHA
const headSha = process.env.HEAD_SHA
const exceptionApproved = process.env.SCOPE_EXCEPTION_APPROVED === 'true'

if (!baseSha || !headSha) {
  throw new Error('UI scope guard requires BASE_SHA and HEAD_SHA')
}

const changed = execFileSync('git', ['diff', '--name-only', '--diff-filter=ACMRT', `${baseSha}...${headSha}`], {
  encoding: 'utf8',
}).split(/\r?\n/).map((value) => value.trim()).filter(Boolean)

const protectedPrefixes = [
  'supabase/migrations/',
  'supabase/tests/database/',
  'server/',
  'worker/',
]

const protectedExact = new Set([
  'src/lib/auth.ts',
  'src/lib/AuthContext.tsx',
  'src/lib/roles.ts',
  'src/lib/routes.ts',
  'src/lib/commands.ts',
  'src/lib/parcelCommands.ts',
  'src/lib/bulkDispatch.ts',
  'src/lib/bulkRto.ts',
  'src/lib/invoice.ts',
  'src/lib/invoicePdf.ts',
  'src/lib/reportFilters.ts',
  'src/lib/excel.ts',
])

const protectedFiles = changed.filter((file) =>
  protectedPrefixes.some((prefix) => file.startsWith(prefix)) || protectedExact.has(file),
)

console.log('UI scope guard')
console.log(`Base: ${baseSha}`)
console.log(`Head: ${headSha}`)
console.log(`Changed files: ${changed.length}`)

if (!protectedFiles.length) {
  console.log('PASS: no protected application/DB contract paths changed.')
  process.exit(0)
}

console.log('Protected paths changed:')
for (const file of protectedFiles) console.log(`- ${file}`)

if (exceptionApproved) {
  console.log('PASS: explicit scope-exception:approved label is present.')
  console.log('A separate scope exception must still be documented and reviewed.')
  process.exit(0)
}

console.error('FAIL: this UI PR changes protected application/DB contract paths.')
console.error('Required action: remove the protected changes or obtain an explicit approved scope-exception label.')
process.exit(1)
