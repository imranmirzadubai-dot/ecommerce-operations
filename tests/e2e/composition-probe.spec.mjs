import { test, expect } from '@playwright/test'

const appOrigin = 'http://127.0.0.1:4173'
const accessToken = 'e2e-access-token'
const userId = 'e2e-user-id'
const compositions = [
  'AdminUserControls,CustomerHistoryWorkspace',
  'AdminUserControls,DispatchScanWorkspace',
  'CustomerHistoryWorkspace,DispatchScanWorkspace',
  'DispatchScanWorkspace,RtoScanWorkspace',
  'RtoScanWorkspace,OrdersWorkspace',
  'OrdersWorkspace,OrderExport',
  'OrderExport,InvoicePrintWorkspace',
  'AdminUserControls,CustomerHistoryWorkspace,DispatchScanWorkspace',
]

async function mockApis(page) {
  await page.route(`${appOrigin}/auth/v1/token**`, async (route) => {
    const grantType = new URL(route.request().url()).searchParams.get('grant_type')
    if (grantType === 'password') {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: accessToken, refresh_token: 'e2e-refresh-token', expires_in: 3600, user: { id: userId } }) })
      return
    }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: `${accessToken}-refresh`, refresh_token: 'e2e-refresh-token-2', expires_in: 3600, user: { id: userId } }) })
  })
  await page.route(`${appOrigin}/rest/v1/profiles**`, async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([{ id: userId, name: 'E2E Test User', email: 'e2e@example.invalid', role: 'admin', active: true }]) })
  })
  await page.route(`${appOrigin}/api/orders**`, async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', headers: { 'X-Has-More': 'false' }, body: JSON.stringify([]) })
  })
}

async function login(page) {
  await page.getByLabel('Email').fill('e2e@example.invalid')
  await page.getByLabel('Password').fill('not-a-real-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
}

for (const composition of compositions) {
  test(`composition probe: ${composition}`, async ({ page }) => {
    const errors = []
    page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`))
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(`console: ${message.text()}`)
    })
    page.on('requestfailed', (request) => errors.push(`requestfailed: ${request.method()} ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`))
    page.on('console', (message) => console.log(`[browser:${message.type()}] ${message.text()}`))

    await mockApis(page)
    const returnTo = `/app?e2eComposition=${encodeURIComponent(composition)}`
    await page.goto(`/login?returnTo=${encodeURIComponent(returnTo)}`, { waitUntil: 'domcontentloaded', timeout: 10_000 })
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
    await login(page)

    await expect(page.locator(`[data-e2e-composition="${composition}"]`), `composition did not commit: ${composition}`).toBeVisible({ timeout: 10_000 })
    for (const component of composition.split(',')) {
      await expect(page.locator(`[data-e2e-component="${component}"]`), `${component} did not commit in ${composition}`).toHaveCount(1, { timeout: 10_000 })
    }
    const heartbeat = await page.evaluate(() => ({ alive: true, pathname: location.pathname, time: Date.now() }))
    console.log(`[COMPOSITION-RESULT] ${JSON.stringify({ composition, heartbeat, errors })}`)
    expect(errors).toEqual([])
  })
}
