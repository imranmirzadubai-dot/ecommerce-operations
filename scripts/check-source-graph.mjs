import { readdir, readFile } from 'node:fs/promises'
import { extname, join, relative, resolve, dirname, basename } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../src')
const SOURCE_EXTENSIONS = new Set(['.ts', '.tsx', '.js', '.jsx'])
const RESOLUTION_EXTENSIONS = ['.ts', '.tsx', '.js', '.jsx']

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) files.push(...await walk(path))
    else if (SOURCE_EXTENSIONS.has(extname(entry.name))) files.push(path)
  }
  return files
}

const files = await walk(ROOT)
const fileSet = new Set(files.map((file) => resolve(file)))
const failures = []

// A module stem is ambiguous when the same relative path exists with more than one
// executable source extension. This is the class of defect that caused OrdersWorkspace.
const stems = new Map()
for (const file of files) {
  const stem = join(dirname(file), basename(file, extname(file)))
  const matches = stems.get(stem) ?? []
  matches.push(file)
  stems.set(stem, matches)
}

for (const [stem, matches] of stems) {
  if (matches.length > 1) {
    failures.push(`duplicate module stem: ${relative(ROOT, stem)} -> ${matches.map((file) => extname(file)).join(', ')}`)
  }
}

function resolveRelativeImport(fromFile, specifier) {
  if (!specifier.startsWith('.')) return null
  const base = resolve(dirname(fromFile), specifier)
  if (fileSet.has(base) && SOURCE_EXTENSIONS.has(extname(base))) return base
  for (const extension of RESOLUTION_EXTENSIONS) {
    const candidate = `${base}${extension}`
    if (fileSet.has(candidate)) return candidate
  }
  for (const extension of RESOLUTION_EXTENSIONS) {
    const candidate = join(base, `index${extension}`)
    if (fileSet.has(candidate)) return candidate
  }
  return null
}

const graph = new Map(files.map((file) => [resolve(file), []]))
const importPattern = /(?:import(?:\s+[^'";]*?\s+from\s+|\s*)|export(?:\s+[^'";]*?\s+from\s+)|import\s*\()(['"])([^'"]+)\1/g

for (const file of files) {
  const source = await readFile(file, 'utf8')
  for (const match of source.matchAll(importPattern)) {
    const target = resolveRelativeImport(file, match[2])
    if (target) graph.get(resolve(file)).push(target)
  }
}

const state = new Map()
const stack = []
const cycleKeys = new Set()

function visit(node) {
  state.set(node, 'visiting')
  stack.push(node)
  for (const next of graph.get(node) ?? []) {
    if (state.get(next) === 'visiting') {
      const start = stack.indexOf(next)
      const cycle = [...stack.slice(start), next]
      const key = cycle.slice(0, -1).map((file) => relative(ROOT, file)).sort().join('|')
      if (!cycleKeys.has(key)) {
        cycleKeys.add(key)
        failures.push(`import cycle: ${cycle.map((file) => relative(ROOT, file)).join(' -> ')}`)
      }
    } else if (!state.has(next)) {
      visit(next)
    }
  }
  stack.pop()
  state.set(node, 'visited')
}

for (const file of files) {
  if (!state.has(file)) visit(file)
}

if (failures.length) {
  console.error('ARCH-005 source graph integrity check failed:')
  for (const failure of failures) console.error(`- ${failure}`)
  process.exit(1)
}

console.log(`ARCH-005 source graph integrity check passed: ${files.length} source modules, no duplicate stems, no relative import cycles.`)
