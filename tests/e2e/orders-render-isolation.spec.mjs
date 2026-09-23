import { test, expect } from '@playwright/test'

const session = {
  access_token: 'e2e-fresh-token',
  token_type: 'bearer',
  expires_in: 3600,
  expires_at: Math.floor(Date.now() / 1000) + 3600,
  refresh_token: 'e2e-refresh-token',
  user: { id: '00000000-0000-0000-0000-000000000001', email: 'e2e@example.test' },
}

const profile = {
  id: session.user.id,
  name: 'E2E Admin',
  email: session.user.email,
  role: 'admin',
  active: true,
}

test('OrdersWorkspace render/effect isolation', async ({ page }) => {
  await page.route('**/auth/v1/**', async (route) => {
    const request = route.request()
    if (request.method() === 'POST' && request.url().includes('/token')) {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(session) })
      return
    }
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.route('**/rest/v1/profiles**', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([profile]) })
  })

  const ordersRequests = []
  await page.route('**/api/orders**', async (route) => {
    ordersRequests.push(route.request().url())
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ orders: [], page: 1, hasMore: false, search: '' }) })
  })

  const logs = []
  page.on('console', (message) => logs.push(`[console:${message.type()}] ${message.text()}`))
  page.on('pageerror', (error) => logs.push(`[pageerror] ${error.message}`))

  await page.goto('/login?returnTo=%2Fapp%3Fe2eComponent%3DOrdersWorkspace%26e2eOrdersNoStartup%3D1', { waitUntil: 'domcontentloaded' })
  await page.getByLabel('Email').fill(session.user.email)
  await page.getByLabel('Password').fill('e2e-password')
  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page.locator('[data-e2e-component="OrdersWorkspace"]')).toBeVisible({ timeout: 8000 })
  await expect(page.getByRole('heading', { name: 'Recent Orders' })).toBeVisible({ timeout: 8000 })
  const heartbeat = await page.evaluate(() => ({ alive: true, pathname: location.pathname, time: Date.now() }))

  expect(heartbeat.alive).toBe(true)
  expect(heartbeat.pathname).toBe('/app')
  expect(ordersRequests).toEqual([])
  expect(logs.some((entry) => entry.includes('[ORDERS-STARTUP-EFFECT-SUPPRESSED]'))).toBe(true)
})
