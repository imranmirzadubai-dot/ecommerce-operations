import assert from 'node:assert/strict';
import test from 'node:test';
import { createMetricSample, measureDuration, measureAsyncDuration } from '../../src/lib/metrics.ts';

test('metric sample validates and serializes deterministic fields', () => {
  const sample = createMetricSample('orders.query.duration', 12.5, 'ms', { report: 'orders' }, new Date('2026-09-20T08:00:00.000Z'));
  assert.deepEqual(sample, {
    name: 'orders.query.duration', value: 12.5, unit: 'ms', timestamp: '2026-09-20T08:00:00.000Z', tags: { report: 'orders' },
  });
});

test('duration measurement returns operation result and elapsed metric', () => {
  let clock = 100;
  const measured = measureDuration('orders.load.duration', () => 'ok', { operation: 'load' }, () => (clock += 25));
  assert.equal(measured.result, 'ok');
  assert.equal(measured.metric.value, 25);
  assert.equal(measured.metric.unit, 'ms');
});

test('async duration measurement preserves result and elapsed metric', async () => {
  let clock = 200;
  const measured = await measureAsyncDuration('reports.fetch.duration', async () => 42, {}, () => (clock += 40));
  assert.equal(measured.result, 42);
  assert.equal(measured.metric.value, 40);
});

test('invalid metric values are rejected', () => {
  assert.throws(() => createMetricSample('', 1, 'count'), /Metric name is required/);
  assert.throws(() => createMetricSample('bad', -1, 'count'), /finite non-negative/);
  assert.throws(() => createMetricSample('bad', Number.NaN, 'count'), /finite non-negative/);
});
