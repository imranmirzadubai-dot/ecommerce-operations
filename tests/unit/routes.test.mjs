import test from 'node:test'
import assert from 'node:assert/strict'
import { getLoginRedirect, getPostLoginPath, isProtectedPath, isPublicPath, safeReturnPath } from '../../src/lib/routes.ts'

test('application paths are protected and login is public', () => {
  assert.equal(isProtectedPath('/'), true)
  assert.equal(isProtectedPath('/orders'), true)
  assert.equal(isProtectedPath('/login'), false)
  assert.equal(isPublicPath('/login'), true)
})

test('unsafe destinations cannot become open redirects', () => {
  assert.equal(safeReturnPath('/'), '/')
  assert.equal(safeReturnPath('/orders', '?tab=ready'), '/orders?tab=ready')
  assert.equal(safeReturnPath('//evil.example'), '/')
  assert.equal(safeReturnPath('https://evil.example'), '/')
  assert.equal(getLoginRedirect('/orders', '?tab=ready'), '/login?returnTo=%2Forders%3Ftab%3Dready')
})

test('protected destination survives login through an encoded return path', () => {
  const redirect = getLoginRedirect('/orders', '?tab=ready')
  assert.equal(redirect, '/login?returnTo=%2Forders%3Ftab%3Dready')
  assert.equal(getPostLoginPath('?returnTo=%2Forders%3Ftab%3Dready'), '/orders?tab=ready')
})

test('post-login return path rejects external and malformed destinations', () => {
  assert.equal(getPostLoginPath('?returnTo=https%3A%2F%2Fevil.example'), '/')
  assert.equal(getPostLoginPath('?returnTo=%2F%2Fevil.example'), '/')
  assert.equal(getPostLoginPath('?returnTo=%2Ffoo%5C%5Cevil'), '/')
  assert.equal(getPostLoginPath('not-a-query'), '/')
})
