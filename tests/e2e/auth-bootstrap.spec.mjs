import { test, expect } from '@playwright/test'

const sessionKey = 'ecommerce-operations.auth.session'
const accessToken = 'e2e-access-token'
const userId = 'e2e-user-id'

async function mockAuthApi(page) {
  let refreshCount = 0
  await page.route('**/auth/v1/token?grant_type=password', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ access_token: accessToken, refresh_token: 'e2e-refresh-token', expires_in: 3600, user: { id: userId } }),
    })
  })
  await page.route('**/auth/v1/token?grant_type=refresh_token', async (route) => {
    refreshCount += 1
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ access_token: `${accessToken}-${refreshCount}`, refresh_token: 'e2e-refresh-token-2', expires_in: 3600, user: { id: userId } }),
    })
  })
  await page.route('**/rest/v1/profiles?id=eq.e2e-user-id*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([{ id: userId, name: 'E2E Test User', email: 'e2e@example.invalid', role: 'admin', active: true }]),
    })
  })
  await page.route('**/auth/v1/logout', async (route) => {
    await route.fulfill({ status: 204, body: '' })
  })
  return { getRefreshCount: () => refreshCount }
}

test.describe('authentication bootstrap', () => {
  test('public login route boots and remains responsive', async ({ page }) => {
    const started = Date.now()
    await page.goto('/login', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await expect(page.locator('body')).toContainText(/authentication|sign in|login|email/i)
    expect(Date.now() - started).toBeLessThan(10_000)
  })

  test('protected route redirects unauthenticated users to login', async ({ page }) => {
    await page.goto('/app', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await expect.poll(() => new URL(page.url()).pathname).toBe('/login')
    await expect.poll(() => new URL(page.url()).searchParams.get('returnTo')).toBe('/app')
  })

  test('login, API session refresh, and logout lifecycle works without real credentials', async ({ page }) => {
    const mock = await mockAuthApi(page)
    await page.goto('/login?returnTo=%2Fapp', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await page.getByLabel('Email').fill('e2e@example.invalid')
    await page.getByLabel('Password').fill('not-a-real-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect.poll(() => new URL(page.url()).pathname).toBe('/app')
    await expect(page.getByText('E2E Test User')).toBeVisible()
    await expect(page.getByText('Authenticated')).toBeVisible()

    await page.evaluate((key) => {
      const raw = localStorage.getItem(key)
      if (!raw) throw new Error('Expected authenticated session in localStorage')
      const session = JSON.parse(raw)
      session.expiresAt = Date.now() + 1000
      localStorage.setItem(key, JSON.stringify(session))
    }, sessionKey)
    await page.reload({ waitUntil: 'domcontentloaded' })
    await expect.poll(() => mock.getRefreshCount()).toBe(1)
    await expect(page.getByText('E2E Test User')).toBeVisible()

    await page.getByRole('button', { name: 'Sign out' }).click()
    await expect.poll(() => new URL(page.url()).pathname).toBe('/login')
    await expect(page.evaluate((key) => localStorage.getItem(key), sessionKey)).toBeNull()
  })
})
