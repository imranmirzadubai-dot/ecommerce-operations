import { test, expect } from '@playwright/test'

const PROFILE = {
  id: 'e2e-t227-006-user',
  name: 'T227 Lifecycle User',
  email: 't227-006@example.test',
  role: 'admin',
  active: true,
}

const AUTH_RESPONSE = {
  accessToken: 'e30.invalid.e2e-token',
  userId: PROFILE.id,
}

for (const strict of ['on', 'off'] as const) {
  test(`T227-006 authenticated startup with StrictMode ${strict}`, async ({ page }, testInfo) => {
    let sessionRequests = 0
    let sessionAuthenticated = false
    const pageErrors: string[] = []
    const requestFailures: string[] = []

    page.on('pageerror', (error) => pageErrors.push(error.message))
    page.on('requestfailed', (request) => requestFailures.push(`${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`))

    await page.route('**/api/auth/session', async (route) => {
      sessionRequests += 1
      if (sessionAuthenticated) {
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(AUTH_RESPONSE) })
      } else {
        await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'authentication_required' }) })
      }
    })
    await page.route('**/api/auth/sign-in', async (route) => {
      sessionAuthenticated = true
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(AUTH_RESPONSE) })
    })
    await page.route('**/rest/v1/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([]) })
    })
    await page.route('**/rest/v1/profiles*', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([PROFILE]) })
    })

    await page.goto(`/login?returnTo=%2F%3Ft227%3D006%26strict=${strict}&strict=${strict}`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('Secure access is required')).toBeVisible()
    await page.getByLabel('Email').fill(PROFILE.email)
    await page.getByLabel('Password').fill('diagnostic-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(/\?t227=006&strict=(on|off)$/)
    await expect(page.getByText('Operations Dashboard', { exact: true })).toBeVisible()
    await expect(page.getByText('Recent Orders', { exact: true })).toBeVisible()

    expect(pageErrors, `${strict}: page errors`).toEqual([])
    expect(requestFailures, `${strict}: request failures`).toEqual([])

    await testInfo.attach(`T227-006-strictmode-${strict}-evidence.json`, {
      body: JSON.stringify({
        task: 'T227-006',
        strictMode: strict === 'on',
        sessionRequests,
        pageErrors,
        requestFailures,
        browser: testInfo.project.name,
      }, null, 2),
      contentType: 'application/json',
    })
  })
}
