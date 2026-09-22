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

  await page.route(`${appOrigin}/auth/v1/token**`, async (route) => {
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

  await page.route(`${appOrigin}/rest/v1/profiles**`, async (route) => {
    profileRequestCount += 1
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([{ id: userId, name: 'E2E Test User', email: 'e2e@example.invalid', role: 'admin', active: true }]) })
  })

  await page.route(`${appOrigin}/auth/v1/logout**`, async (route) => {
    logoutRequestCount += 1
    await route.fulfill({ status: 204, body: '' })
  })

  await page.route(`${appOrigin}/api/orders**`, async (route) => {
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

async function installStorageDiagnostics(page) {
  await page.addInitScript(({ key }) => {
    window.__storageDiagnostics = []
    const record = (event) => {
      window.__storageDiagnostics.push({ ...event, stack: new Error().stack ?? '' })
    }
    const originalRemoveItem = Storage.prototype.removeItem
    const originalClear = Storage.prototype.clear
    const originalSetItem = Storage.prototype.setItem
    Storage.prototype.removeItem = function (storageKey) {
      if (this === localStorage && storageKey === key) record({ operation: 'removeItem', key: storageKey })
      return originalRemoveItem.call(this, storageKey)
    }
    Storage.prototype.clear = function () {
      if (this === localStorage) record({ operation: 'clear' })
      return originalClear.call(this)
    }
    Storage.prototype.setItem = function (storageKey, value) {
      if (this === localStorage && storageKey === key) record({ operation: 'setItem', key: storageKey, value })
      return originalSetItem.call(this, storageKey, value)
    }
  }, { key: sessionKey })
}

async function diagnostics(page) {
  return page.evaluate((key) => ({
    url: location.href,
    session: localStorage.getItem(key),
    storageEvents: window.__storageDiagnostics ?? [],
    trace: window.__e2eAuthTrace ?? [],
  }), sessionKey)
}

async function login(page) {
  await page.getByLabel('Email').fill('e2e@example.invalid')
  await page.getByLabel('Password').fill('not-a-real-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
}

test.describe('authentication bootstrap', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (message) => console.log(`[browser:${message.type()}] ${message.text()}`))
    page.on('pageerror', (error) => console.log(`[browser:pageerror] ${error.message}`))
    page.on('framenavigated', (frame) => console.log(`[NAVIGATION] ${frame.url()}`))
    await installStorageDiagnostics(page)
  })

  test('public login route boots and remains responsive', async ({ page }) => {
    const started = Date.now()
    await page.goto('/login', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    const buildStamp = await page.evaluate(() => window.__buildStamp)
    console.log('BUILD UNDER TEST:', JSON.stringify(buildStamp))
    expect(buildStamp?.sha).toBe(process.env.GITHUB_SHA)
    await expect(page.locator('body')).toContainText(/authentication|sign in|login|email/i)
    expect(Date.now() - started).toBeLessThan(10_000)
  })

  test('protected route redirects unauthenticated users to login', async ({ page }) => {
    await page.goto('/app', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await expect.poll(() => new URL(page.url()).pathname).toBe('/login')
    await expect.poll(() => new URL(page.url()).searchParams.get('returnTo')).toBe('/app')
  })

  test('login, authenticated API, session refresh, and logout lifecycle works without real credentials', async ({ page }) => {
    const providerMounts = []
    page.on('console', (message) => {
      const match = message.text().match(/\[AUTH_EVENT\] provider_mount (\S+)/)
      if (match) providerMounts.push(match[1])
    })
    const mock = await mockAuthApi(page)
    await page.addInitScript(() => {
      window.__e2eAuthTrace = []
      const originalInfo = console.info
      console.info = (...args) => {
        if (args[0] === '[AUTH-E2E]') window.__e2eAuthTrace.push(args.slice(1).join(' '))
        originalInfo(...args)
      }
    })
    const browserErrors = []
    page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`))
    page.on('console', (message) => {
      if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`)
    })
    page.on('requestfailed', (request) => browserErrors.push(`requestfailed: ${request.method()} ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`))

    await page.goto('/login?returnTo=%2Fapp', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await login(page)

    await expect.poll(() => mock.getTokenRequestCount(), { timeout: 10_000 }).toBe(1)
    await expect.poll(() => mock.getProfileRequestCount(), { timeout: 10_000 }).toBeGreaterThan(0)
    await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), sessionKey), { timeout: 10_000, message: async () => `Session missing after token/profile lifecycle; diagnostics=${JSON.stringify(await diagnostics(page))}; stamp=${JSON.stringify(await page.evaluate(() => window.__buildStamp))}; mounts=${providerMounts.join(',') || 'none'}` }).toBeTruthy()
    expect(browserErrors).toEqual([])
    await expect.poll(() => new URL(page.url()).pathname, { timeout: 10_000, message: async () => `Unexpected URL; diagnostics=${JSON.stringify(await diagnostics(page))}; stamp=${JSON.stringify(await page.evaluate(() => window.__buildStamp))}; mounts=${providerMounts.join(',') || 'none'}` }).toBe('/app')
    expect(new Set(providerMounts).size).toBe(1)
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

  test('signIn wins over a slower concurrent restoreSession', async ({ page }) => {
    await page.addInitScript(({ key, token, uid }) => {
      localStorage.setItem(key, JSON.stringify({ accessToken: token, refreshToken: 'e2e-refresh-token', expiresAt: Date.now() + 3600_000, userId: uid }))
      window.__e2eAuthTrace = []
      const originalInfo = console.info
      console.info = (...args) => {
        if (args[0] === '[AUTH-E2E]') window.__e2eAuthTrace.push(args.slice(1).join(' '))
        originalInfo(...args)
      }
    }, { key: sessionKey, token: 'stale-restore-token', uid: userId })

    let profileCallCount = 0
    let staleRestoreFinished = false

    await page.route(`${appOrigin}/auth/v1/token**`, async (route) => {
      const grantType = new URL(route.request().url()).searchParams.get('grant_type')
      if (grantType === 'password') {
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: accessToken, refresh_token: 'e2e-refresh-token', expires_in: 3600, user: { id: userId } }) })
        return
      }
      if (grantType === 'refresh_token') {
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: `${accessToken}-refresh`, refresh_token: 'e2e-refresh-token-2', expires_in: 3600, user: { id: userId } }) })
        return
      }
      await route.continue()
    })

    await page.route(`${appOrigin}/rest/v1/profiles**`, async (route) => {
      profileCallCount += 1
      const authorization = route.request().headers().authorization ?? ''
      if (authorization === 'Bearer stale-restore-token') {
        await new Promise((resolve) => setTimeout(resolve, 500))
        staleRestoreFinished = true
      }
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([{ id: userId, name: 'E2E Test User', email: 'e2e@example.invalid', role: 'admin', active: true }]) })
    })

    await page.route(`${appOrigin}/api/orders**`, async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', headers: { 'X-Has-More': 'false' }, body: JSON.stringify([]) })
    })

    await page.goto('/login?returnTo=%2Fapp', { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
    await login(page)

    await expect(page).toHaveURL(`${appOrigin}/app`)
    await expect(page.getByText('E2E Test User')).toBeVisible()
    await expect.poll(() => profileCallCount).toBeGreaterThanOrEqual(2)
    await expect.poll(() => staleRestoreFinished, { timeout: 2_000 }).toBe(true)
    await expect(page).toHaveURL(`${appOrigin}/app`)
    await expect(page.getByText('Authenticated')).toBeVisible()
    await expect(page.evaluate((key) => JSON.parse(localStorage.getItem(key)).accessToken, sessionKey)).toBe(accessToken)
  })
})
