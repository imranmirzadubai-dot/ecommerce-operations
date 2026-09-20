import assert from 'node:assert/strict';
import test from 'node:test';
import { createCorrelationId, createCorrelationContext, correlationHeaders } from '../../src/lib/correlation.ts';

test('valid supplied correlation id is preserved', () => {
  assert.equal(createCorrelationId('req-2026-09-20-001'), 'req-2026-09-20-001');
});

test('invalid or missing correlation id is replaced with a generated id', () => {
  const generated = createCorrelationId('bad value with spaces');
  assert.match(generated, /^[A-Za-z0-9._:-]{1,128}$/);
  assert.notEqual(generated, 'bad value with spaces');
});

test('correlation context and HTTP header use the same identifier', () => {
  const context = createCorrelationContext('order-load-42');
  assert.deepEqual(context, { correlationId: 'order-load-42' });
  assert.deepEqual(correlationHeaders(context.correlationId), { 'X-Correlation-ID': 'order-load-42' });
});

test('correlation id is bounded and safe for a request header', () => {
  const value = createCorrelationId('x'.repeat(129));
  assert.ok(value.length <= 128);
  assert.ok(!/[\r\n]/.test(value));
});
