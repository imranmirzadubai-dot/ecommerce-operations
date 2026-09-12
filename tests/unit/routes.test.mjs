import test from 'node:test'
import assert from 'node:assert/strict'
import { getLoginRedirect, getPostLoginPath, isProtectedPath, isPublicPath, safeReturnPath } from '../../src/lib/routes.mjs'

test('application paths are protected and login is public', () => {
  assert.equal(isProtectedPath('/app'), true)
  assert.equal(isProtectedPath('/app/orders'), true)
  assert.equal(isProtectedPath('/login'), false)
  assert.equal(isPublicPath('/login'), true)
})

test('non-application paths cannot become open redirects', () => {
  assert.equal(safeReturnPath('/'), '/app')
  assert.equal(safeReturnPath('https://evil.example'), '/app')
  assert.equal(getLoginRedirect('/'), '/login?returnTo=%2Fapp')
})

test('protected destination survives login through an encoded return path', () => {
  const redirect = getLoginRedirect('/app/orders', '?tab=ready')
  assert.equal(redirect, '/login?returnTo=%2Fapp%2Forders%3Ftab%3Dready')
  assert.equal(getPostLoginPath('?returnTo=%2Fapp%2Forders%3Ftab%3Dready'), '/app/orders?tab=ready')
})

test('post-login return path rejects external and malformed destinations', () => {
  assert.equal(getPostLoginPath('?returnTo=https%3A%2F%2Fevil.example'), '/app')
  assert.equal(getPostLoginPath('?returnTo=%2F%2Fevil.example'), '/app')
  assert.equal(getPostLoginPath('?returnTo=%2Fapp%2Ffoo%5C%5Cevil'), '/app')
})
