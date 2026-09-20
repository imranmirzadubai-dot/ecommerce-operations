import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql = fs.readFileSync('supabase/tests/database/124_query_plan_review.sql', 'utf8');

test('P14-T213 query-plan contract is rollback-scoped and uses analyzed plans', () => {
  assert.match(sql, /select plan\(16\)/);
  assert.match(sql, /begin;/);
  assert.match(sql, /set local role postgres/);
  assert.match(sql, /analyze public\.customers/);
  assert.match(sql, /analyze public\.orders/);
  assert.match(sql, /analyze public\.parcels/);
  assert.match(sql, /EXPLAIN \(ANALYZE, BUFFERS, FORMAT JSON\)/);
  assert.match(sql, /idx_orders_customer_id/);
  assert.match(sql, /idx_orders_order_date/);
  assert.match(sql, /idx_orders_lifecycle_state/);
  assert.match(sql, /idx_parcels_order_id/);
  assert.match(sql, /idx_parcels_state/);
  assert.match(sql, /idx_parcels_tracking_id/);
  assert.match(sql, /idx_delivery_outcomes_parcel_id/);
  assert.match(sql, /rollback;/);
});
