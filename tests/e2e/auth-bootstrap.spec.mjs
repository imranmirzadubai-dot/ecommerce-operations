import { test, expect } from '@playwright/test'

const sessionKey = 'ecommerce-operations.auth.session'
const accessToken = 'e2e-access-token'
const userId = 'e2e-user-id'
const authOrigin = 'https://e2e.invalid'

async function mockAuthApi(page) {
  let refreshCount = 0
  let ordersRequestCount = 0
  let ordersAuthorization = null

  await page.route(`${authOrigin}/**`, async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const requestOrigin = request.headers().origin ?? 'http://127.0.0.1:4173'
    const corsHeaders = {
      'Access-Control-Allow-Origin': requestOrigin,
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'apikey,authorization,content-type,x-client-info',
    }

    if (request.method() === 'OPTIONS') {
      await route.fulfill({ status: 204, headers: corsHeaders, body: '' })
      return
    }

    if (url.pathname === '/auth/v1/token') {
      const grantType = url.searchParams.get('grant_type')
      if (grantType === 'refresh_token') {
        refreshCount += 1
        await route.fulfill({ status: 200, contentType: 'application/json', headers: corsHeaders, body: JSON.stringify({ access_token: `${accessToken}-${refreshCount}`, refresh_token: 'e2e-refresh-token-2', expires_in: 3600, user: { id: userId } }) })
        return
      }
      if (grantType === 'password') {
        await route.fulfill({ status: 200, contentType: 'application/json', headers: corsHeaders, body: JSON.stringify({ access_token: accessToken, refresh_token: 'e2e-refresh-token', expires_in: 3600, user: { id: userId } }) })
        return
      }
    }
    if (url.pathname === '/rest/v1/profiles') {
      await route.fulfill({ status: 200, contentType: 'application/json', headers: corsHeaders, body: JSON.stringify([{ id: userId, name: 'E2E Test User', email: 'e2e@example.invalid', role: 'admin', active: true }]) })
      return
    }
    if (url.pathname === '/auth/v1/logout') {
      await route.fulfill({ status: 204, headers: corsHeaders, body: '' })
      return
    }
    await route.continue()
  })
  await page.route('**/api/orders*', async (route) => {
    ordersRequestCount += 1
    ordersAuthorization = route.request().headers().authorization ?? null
    await route.fulfill({ status: 200, contentType: 'application/json', headers: { 'X-Has-More': 'false' }, body: JSON.stringify([]) })
  })
  return {
    getRefreshCount: () => refreshCount,
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
    await page.goto('/login?returnTo=%2Fapp', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await page.getByLabel('Email').fill('e2e@example.invalid')
    await page.getByLabel('Password').fill('not-a-real-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect.poll(() => page.evaluate((key) => localStorage.getItem(key) !== null, sessionKey), { timeout: 10_000 }).toBe(true)
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
    await expect.poll(() => new URL(page.url()).pathname).toBe('/login')
    await expect(page.evaluate((key) => localStorage.getItem(key), sessionKey)).toBeNull()
  })
})
