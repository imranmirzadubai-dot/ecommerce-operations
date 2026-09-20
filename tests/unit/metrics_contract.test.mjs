import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

test('performance metrics implementation remains dependency-free and exposes duration helpers', () => {
  const source = readFileSync(new URL('../../src/lib/metrics.ts', import.meta.url), 'utf8');
  assert.match(source, /export function createMetricSample/);
  assert.match(source, /export function measureDuration/);
  assert.match(source, /export async function measureAsyncDuration/);
  assert.match(source, /performance\.now/);
  assert.doesNotMatch(source, /from ['"](prom-client|@opentelemetry|sentry)/);
});
