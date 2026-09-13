import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const migration = fs.readFileSync(
  new URL('../../supabase/migrations/20260914010000_invoice_template_version_lineage.sql', import.meta.url),
  'utf8',
)

test('invoice template lineage is a first-class versioned record', () => {
  assert.match(migration, /create table if not exists public\.invoice_template_versions/)
  assert.match(migration, /version text primary key/)
  assert.match(migration, /template_key text not null/)
  assert.match(migration, /renderer_revision text not null/)
  assert.match(migration, /supersedes_version text references public\.invoice_template_versions\(version\)/)
})

test('invoice records are anchored to the immutable template version', () => {
  assert.match(migration, /invoice_records_template_version_fkey/)
  assert.match(migration, /references public\.invoice_template_versions\(version\)/)
  assert.match(migration, /on delete restrict/)
})

test('template versions cannot be mutated after creation', () => {
  assert.match(migration, /prevent_invoice_template_version_mutation/)
  assert.match(migration, /before update or delete on public\.invoice_template_versions/)
  assert.match(migration, /Invoice template versions are immutable/)
})

test('template lineage is readable only to authenticated operational roles', () => {
  assert.match(migration, /invoice_template_versions_authenticated_select/)
  assert.match(migration, /public\.app_role\(\) in \('sales','operations','admin'\)/)
  assert.match(migration, /grant select on public\.invoice_template_versions to authenticated/)
})
