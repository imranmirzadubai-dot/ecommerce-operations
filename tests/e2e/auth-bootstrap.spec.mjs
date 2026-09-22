import { test, expect } from '@playwright/test'

const sessionKey = 'ecommerce-operations.auth.session'
const accessToken = 'e2e-access-token'
const userId = 'e2e-user-id'
const appOrigin = 'http://127.0.0.1:4173'

async function mockAuthApi(page) {
  let refreshCount = 0
  let tokenRequestCount = 0
  let profileRequestCount = 0
  let logoutRequestCount = 0
  let ordersRequestCount = 0
  let ordersAuthorization = null

  await page.route((url) => url.origin === appOrigin && url.pathname === '/auth/v1/token', async (route) => {
    tokenRequestCount += 1
    const grantType = new URL(route.request().url()).searchParams.get('grant_type')
    if (grantType === 'refresh_token') {
      refreshCount += 1
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: `${accessToken}-${refreshCount}`, refresh_token: 'e2e-refresh-token-2', expires_in: 3600, user: { id: userId } }) })
      return
    }
    if (grantType === 'password') {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: accessToken, refresh_token: 'e2e-refresh-token', expires_in: 3600, user: { id: userId } }) })
      return
    }
    await route.continue()
  })

  await page.route((url) => url.origin === appOrigin && url.pathname === '/rest/v1/profiles', async (route) => {
    profileRequestCount += 1
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([{ id: userId, name: 'E2E Test User', email: 'e2e@example.invalid', role: 'admin', active: true }]) })
  })

  await page.route((url) => url.origin === appOrigin && url.pathname === '/auth/v1/logout', async (route) => {
    logoutRequestCount += 1
    await route.fulfill({ status: 204, body: '' })
  })

  await page.route((url) => url.origin === appOrigin && url.pathname === '/api/orders', async (route) => {
    ordersRequestCount += 1
    ordersAuthorization = route.request().headers().authorization ?? null
    await route.fulfill({ status: 200, contentType: 'application/json', headers: { 'X-Has-More': 'false' }, body: JSON.stringify([]) })
  })

  return {
    getRefreshCount: () => refreshCount,
    getTokenRequestCount: () => tokenRequestCount,
    getProfileRequestCount: () => profileRequestCount,
    getLogoutRequestCount: () => logoutRequestCount,
    getOrdersRequestCount: () => ordersRequestCount,
    getOrdersAuthorization: () => ordersAuthorization,
  }
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

  test('login, authenticated API, session refresh, and logout lifecycle works without real credentials', async ({ page }) => {
    const mock = await mockAuthApi(page)
    const browserErrors = []
    page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`))
    page.on('console', (message) => {
      if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`)
    })
    page.on('requestfailed', (request) => browserErrors.push(`requestfailed: ${request.method()} ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`))

    await page.goto('/login?returnTo=%2Fapp', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await page.getByLabel('Email').fill('e2e@example.invalid')
    await page.getByLabel('Password').fill('not-a-real-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect.poll(() => mock.getTokenRequestCount(), { timeout: 10_000 }).toBe(1)
    await expect.poll(() => mock.getProfileRequestCount(), { timeout: 10_000 }).toBeGreaterThan(0)
    await expect.poll(async () => ({
      session: await page.evaluate((key) => localStorage.getItem(key), sessionKey),
      url: page.url(),
      errors: browserErrors,
    }), { timeout: 10_000 }).toEqual(expect.objectContaining({ session: expect.any(String) }))
    await expect.poll(() => new URL(page.url()).pathname, { timeout: 10_000 }).toBe('/app')
    await expect(page.getByText('E2E Test User')).toBeVisible()
    await expect(page.getByText('Authenticated')).toBeVisible()
    await expect.poll(() => mock.getOrdersRequestCount()).toBeGreaterThan(0)
    expect(mock.getOrdersAuthorization()).toBe(`Bearer ${accessToken}`)

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
    await expect.poll(() => mock.getLogoutRequestCount()).toBe(1)
    await expect.poll(() => new URL(page.url()).pathname).toBe('/login')
    await expect(page.evaluate((key) => localStorage.getItem(key), sessionKey)).toBeNull()
  })
})
