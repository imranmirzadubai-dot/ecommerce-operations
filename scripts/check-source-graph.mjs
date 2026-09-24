import { readdir, readFile } from 'node:fs/promises'
import { dirname, extname, join, relative, resolve } from 'node:path'

const ROOT = resolve('src')
const SOURCE_EXTENSIONS = ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs']

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) files.push(...await walk(path))
    else if (SOURCE_EXTENSIONS.includes(extname(entry.name))) files.push(path)
  }
  return files
}

function logicalStem(path) {
  const base = path.slice(0, -extname(path).length)
  return base
}

function parseImports(source) {
  const imports = []
  const patterns = [
    /\bimport\s+(?:[^'"]+?\s+from\s+)?['"]([^'"]+)['"]/g,
    /\bexport\s+(?:[^'"]+?\s+from\s+)?['"]([^'"]+)['"]/g,
    /\bimport\(\s*['"]([^'"]+)['"]\s*\)/g,
  ]
  for (const pattern of patterns) {
    for (const match of source.matchAll(pattern)) imports.push(match[1])
  }
  return imports
}

async function resolveImport(from, specifier, files) {
  if (!specifier.startsWith('.')) return null
  const base = resolve(dirname(from), specifier)
  const candidates = [
    base,
    ...SOURCE_EXTENSIONS.map((extension) => base + extension),
    ...SOURCE_EXTENSIONS.map((extension) => join(base, 'index' + extension)),
  ]
  return candidates.find((candidate) => files.has(candidate)) ?? null
}

function findCycles(graph) {
  const visiting = new Set()
  const visited = new Set()
  const cycles = []

  function visit(node, path) {
    if (visiting.has(node)) {
      const start = path.indexOf(node)
      cycles.push([...path.slice(start), node])
      return
    }
    if (visited.has(node)) return
    visiting.add(node)
    for (const next of graph.get(node) ?? []) visit(next, [...path, node])
    visiting.delete(node)
    visited.add(node)
  }

  for (const node of graph.keys()) visit(node, [])
  return cycles
}

export async function analyzeSourceGraph(root = ROOT) {
  const files = new Set(await walk(root))
  const stems = new Map()
  for (const file of files) {
    const stem = logicalStem(file)
    const existing = stems.get(stem) ?? []
    existing.push(file)
    stems.set(stem, existing)
  }

  const duplicateStems = [...stems.entries()]
    .filter(([, paths]) => paths.length > 1)
    .map(([stem, paths]) => ({ stem, paths }))

  const graph = new Map()
  for (const file of files) {
    const source = await readFile(file, 'utf8')
    const dependencies = new Set()
    for (const specifier of parseImports(source)) {
      const target = await resolveImport(file, specifier, files)
      if (target) dependencies.add(target)
    }
    graph.set(file, dependencies)
  }

  return { duplicateStems, cycles: findCycles(graph) }
}

export function assertSyntheticCycleDetection() {
  const graph = new Map([
    ['A.ts', new Set(['B.ts'])],
    ['B.ts', new Set(['C.ts'])],
    ['C.ts', new Set(['A.ts'])],
  ])
  const cycles = findCycles(graph)
  if (cycles.length === 0) throw new Error('ARCH-005 guard self-test failed: synthetic cycle was not detected')
}

assertSyntheticCycleDetection()

const result = await analyzeSourceGraph()
if (result.duplicateStems.length || result.cycles.length) {
  if (result.duplicateStems.length) {
    console.error('Duplicate logical source stems:')
    for (const duplicate of result.duplicateStems) {
      console.error(' -', relative(process.cwd(), duplicate.stem), duplicate.paths.map((path) => relative(process.cwd(), path)).join(', '))
    }
  }
  if (result.cycles.length) {
    console.error('Circular source imports:')
    for (const cycle of result.cycles) console.error(' -', cycle.map((path) => relative(process.cwd(), path)).join(' -> '))
  }
  process.exit(1)
}

console.log(`ARCH-005 source graph guard passed: ${(await walk(ROOT)).length} source files checked; no duplicate logical stems or circular imports.`)
