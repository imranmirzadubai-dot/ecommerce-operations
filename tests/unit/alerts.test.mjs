import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateAlert, shouldNotify } from '../../src/lib/alerts.ts';

test('above threshold triggers alert', () => {
  const alert = evaluateAlert({ name: 'orders.latency', threshold: 500, severity: 'warning', direction: 'above' }, 501, { route: 'orders' }, new Date('2026-09-20T09:00:00.000Z'));
  assert.equal(alert.triggered, true);
  assert.equal(shouldNotify(alert), true);
  assert.equal(alert.timestamp, '2026-09-20T09:00:00.000Z');
});

test('below threshold remains quiet when condition is not met', () => {
  const alert = evaluateAlert({ name: 'error.rate', threshold: 0.05, severity: 'critical', direction: 'above' }, 0.02);
  assert.equal(alert.triggered, false);
  assert.equal(shouldNotify(alert), false);
});

test('below direction triggers only below threshold', () => {
  const alert = evaluateAlert({ name: 'queue.depth', threshold: 10, severity: 'info', direction: 'below' }, 9);
  assert.equal(alert.triggered, true);
});

test('invalid alert inputs are rejected', () => {
  assert.throws(() => evaluateAlert({ name: '', threshold: 1, severity: 'warning', direction: 'above' }, 2), /Alert name/);
  assert.throws(() => evaluateAlert({ name: 'x', threshold: Number.NaN, severity: 'warning', direction: 'above' }, 2), /threshold/);
  assert.throws(() => evaluateAlert({ name: 'x', threshold: 1, severity: 'warning', direction: 'above' }, Number.NaN), /value/);
});
