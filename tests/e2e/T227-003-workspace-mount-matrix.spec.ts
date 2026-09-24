import { test, expect } from '@playwright/test'

const AUTHENTICATED_PROFILE = {
  id: 'e2e-t227-003-user',
  name: 'T227 Control User',
  email: 't227-003@example.test',
  role: 'admin',
  active: true,
}

const AUTH_RESPONSE = {
  accessToken: 'e30.invalid.e2e-token',
  userId: AUTHENTICATED_PROFILE.id,
}

const MATRIX = [
  ['orders', 'Recent Orders'],
  ['customers', 'Customer History'],
  ['dispatch', 'Scan-first Dispatch'],
  ['rto', 'Scan-first RTO'],
  ['invoices', 'Individual & Batch Printing'],
  ['reports', 'Operational Reports'],
  ['admin', 'User controls'],
] as const

for (const [workspace, expectedTitle] of MATRIX) {
  test(`T227-003 mounts only the ${workspace} workspace`, async ({ page }, testInfo) => {
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

    await page.goto(`/login?returnTo=%2F%3Ft227%3D003%26workspace%3D${workspace}`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('Secure access is required')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
    await page.getByLabel('Email').fill('t227-003@example.test')
    await page.getByLabel('Password').fill('diagnostic-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(new RegExp(`\\?t227=003&workspace=${workspace}$`))
    await expect(page.getByTestId('t227-003-workspace-shell')).toBeVisible()
    await expect(page.getByText(expectedTitle, { exact: true })).toBeVisible()

    for (const [, otherTitle] of MATRIX) {
      if (otherTitle !== expectedTitle) await expect(page.getByText(otherTitle, { exact: true })).toHaveCount(0)
    }

    expect(pageErrors, `${workspace}: page errors`).toEqual([])
    expect(requestFailures, `${workspace}: request failures`).toEqual([])

    await testInfo.attach(`T227-003-${workspace}-evidence.json`, {
      body: JSON.stringify({
        task: 'T227-003',
        workspace,
        expectedTitle,
        authenticated: true,
        isolated: true,
        pageErrors,
        requestFailures,
        browser: testInfo.project.name,
      }, null, 2),
      contentType: 'application/json',
    })
  })
}
