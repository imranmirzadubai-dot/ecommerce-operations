import assert from 'node:assert/strict';
import test from 'node:test';
import { createLogEntry } from '../../src/lib/logger.ts';

test('structured log entry has stable JSON fields', () => {
  const entry = createLogEntry('info', 'order.loaded', { orderId: 'o-1' }, new Date('2026-09-20T07:00:00.000Z'));
  assert.deepEqual(entry, {
    timestamp: '2026-09-20T07:00:00.000Z',
    level: 'info',
    message: 'order.loaded',
    context: { orderId: 'o-1' },
  });
});

test('sensitive authentication values are redacted recursively', () => {
  const entry = createLogEntry('error', 'request.failed', {
    accessToken: 'secret',
    nested: { refresh_token: 'secret-2', authorization: 'Bearer secret-3' },
    safe: 'value',
  });

  assert.deepEqual(entry.context, {
    accessToken: '[REDACTED]',
    nested: { refresh_token: '[REDACTED]', authorization: '[REDACTED]' },
    safe: 'value',
  });
});

test('structured log entry serializes as one JSON object', () => {
  const entry = createLogEntry('warn', 'parcel.delayed', { count: 2 });
  const parsed = JSON.parse(JSON.stringify(entry));
  assert.equal(parsed.level, 'warn');
  assert.equal(parsed.message, 'parcel.delayed');
  assert.equal(parsed.context.count, 2);
});
