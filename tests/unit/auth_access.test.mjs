import test from 'node:test'
import assert from 'node:assert/strict'
import { hasOperationalAccess, canAdministerUsers } from '../../src/lib/auth.ts'

const profile = (role = 'operations', active = true) => ({
  id: '00000000-0000-0000-0000-000000000001',
  name: 'Test User',
  email: 'test@example.com',
  role,
  active,
})

test('active approved roles have operational access', () => {
  for (const role of ['sales', 'operations', 'admin']) {
    assert.equal(hasOperationalAccess(profile(role, true)), true)
  }
})

test('inactive approved roles have no operational access', () => {
  for (const role of ['sales', 'operations', 'admin']) {
    assert.equal(hasOperationalAccess(profile(role, false)), false)
  }
})

test('inactive admins cannot administer users', () => {
  assert.equal(canAdministerUsers(profile('admin', false)), false)
  assert.equal(canAdministerUsers(profile('admin', true)), true)
})

test('missing or unsupported profiles have no access', () => {
  assert.equal(hasOperationalAccess(null), false)
  assert.equal(canAdministerUsers(null), false)
  assert.equal(hasOperationalAccess(profile('unknown', true)), false)
  assert.equal(canAdministerUsers(profile('operations', true)), false)
})
