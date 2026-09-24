import { test, expect } from '@playwright/test'

const AUTHENTICATED_PROFILE = {
  id: 'e2e-t227-005-user',
  name: 'T227 Control User',
  email: 't227-005@example.test',
  role: 'admin',
  active: true,
}

const AUTH_RESPONSE = {
  accessToken: 'e30.invalid.e2e-token',
  userId: AUTHENTICATED_PROFILE.id,
}

for (const navigation of ['hard', 'soft'] as const) {
  test(`T227-005 authenticated startup with ${navigation} post-login navigation`, async ({ page }, testInfo) => {
    let sessionAuthenticated = false
    const pageErrors: string[] = []
    const requestFailures: string[] = []
    let postLoginNavigations = 0

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

    await page.goto(`/login?returnTo=%2F%3Ft227%3D005%26navigation=${navigation}`, { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('Secure access is required')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()

    let trackingPostLogin = true
    page.on('framenavigated', (frame) => {
      if (frame === page.mainFrame() && trackingPostLogin) postLoginNavigations += 1
    })

    await page.getByLabel('Email').fill('t227-005@example.test')
    await page.getByLabel('Password').fill('diagnostic-password')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(/\?t227=005&navigation=(hard|soft)$/)
    await expect(page.getByText('Operations Dashboard', { exact: true })).toBeVisible()
    await expect(page.getByText('Recent Orders', { exact: true })).toBeVisible()
    trackingPostLogin = false

    if (navigation === 'hard') {
      expect(postLoginNavigations).toBeGreaterThanOrEqual(1)
    } else {
      expect(postLoginNavigations).toBe(0)
    }

    expect(pageErrors, `${navigation}: page errors`).toEqual([])
    expect(requestFailures, `${navigation}: request failures`).toEqual([])

    await testInfo.attach(`T227-005-navigation-${navigation}-evidence.json`, {
      body: JSON.stringify({
        task: 'T227-005',
        navigation,
        authenticated: true,
        postLoginNavigations,
        pageErrors,
        requestFailures,
        browser: testInfo.project.name,
      }, null, 2),
      contentType: 'application/json',
    })
  })
}
