import { test, expect } from '@playwright/test'

const AUTHENTICATED_PROFILE = {
  id: 'e2e-t227-004-user',
  name: 'T227 Control User',
  email: 't227-004@example.test',
  role: 'admin',
  active: true,
}

const AUTH_RESPONSE = {
  accessToken: 'e30.invalid.e2e-token',
  userId: AUTHENTICATED_PROFILE.id,
}

for (const orders of ['off', 'on'] as const) {
  test(`T227-004 authenticated shell starts with Orders ${orders}`, async ({ page }, testInfo) => {
    let sessionAuthenticated = false
    const pageErrors: string[] = []
    const requestFailures: string[] = []

    page.on('pageerror', (error) => pageErrors.push(error.message))
    page.on('requestfailed', (request) => requestFailures.push(`${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`))

    await page.route('**/api/auth/session', async (route) => {
      if (sessionAuthenticated) {
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(AUTH_RESPONSE) })
        return
      }
      await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'authentication_required' }) })
    })
    await page.route('**/api/auth/sign-in', async (route) => {
      sessionAuthenticated = true
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(AUTH_RESPONSE) })
    })
    await page.route('**/api/auth/sign-out', async (route) => {
      sessionAuthenticated = false
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({}) })
    })
    await page.route('**/rest/v1/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([]) })
    })
    await page.route('**/rest/v1/profiles*', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([AUTHENTICATED_PROFILE]) })
    })

    await page.goto(`/login?returnTo=%2F%3Ft227%3D003%26orders%3D${orders}`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('Secure access is required')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
    await page.getByLabel('Email').fill('t227-004@example.test')
    await page.getByLabel('Password').fill('diagnostic-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(new RegExp(`\\?t227=003&orders=${orders}$`))
    await expect(page.getByText('Operations Dashboard', { exact: true })).toBeVisible()

    if (orders === 'on') {
      await expect(page.getByText('Recent Orders', { exact: true })).toBeVisible()
    } else {
      await expect(page.getByText('Recent Orders', { exact: true })).toHaveCount(0)
    }

    expect(pageErrors, `${orders}: page errors`).toEqual([])
    expect(requestFailures, `${orders}: request failures`).toEqual([])

    await testInfo.attach(`T227-004-orders-${orders}-evidence.json`, {
      body: JSON.stringify({
        task: 'T227-004',
        orders,
        authenticated: true,
        ordersMounted: orders === 'on',
        pageErrors,
        requestFailures,
        browser: testInfo.project.name,
      }, null, 2),
      contentType: 'application/json',
    })
  })
}
