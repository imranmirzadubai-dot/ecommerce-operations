import test from 'node:test'
import assert from 'node:assert/strict'
import { APP_ROLES, APP_ROLE_LABELS, isAppRole, roleLabel } from '../../src/lib/roles.ts'

test('application roles are exactly the approved role set', () => {
  assert.deepEqual([...APP_ROLES], ['sales', 'operations', 'admin'])
  assert.deepEqual(APP_ROLE_LABELS, { sales: 'Sales', operations: 'Operations', admin: 'Admin' })
})

test('role validation accepts only approved application roles', () => {
  for (const role of APP_ROLES) assert.equal(isAppRole(role), true)
  for (const value of [null, undefined, '', 'user', 'manager', 'Sales', 1, {}, ['admin']]) {
    assert.equal(isAppRole(value), false)
  }
})

test('approved roles have stable display labels', () => {
  assert.equal(roleLabel('sales'), 'Sales')
  assert.equal(roleLabel('operations'), 'Operations')
  assert.equal(roleLabel('admin'), 'Admin')
})
