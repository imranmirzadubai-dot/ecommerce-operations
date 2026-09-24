import { test, expect } from '@playwright/test'

const AUTHENTICATED_PROFILE = {
  id: 'e2e-t227-002-user',
  name: 'T227 Control User',
  email: 't227-002@example.test',
  role: 'admin',
  active: true,
}

const AUTH_RESPONSE = {
  accessToken: 'e30.invalid.e2e-token',
  userId: AUTHENTICATED_PROFILE.id,
}

test('T227-002 authenticated shell isolates navigation from operational tree', async ({ page }, testInfo) => {
  const evidence = {
    task: 'T227-002',
    commit: process.env.GITHUB_SHA ?? 'local',
    environment: process.env.VITE_APP_ENVIRONMENT ?? 'unknown',
    browser: testInfo.project.name,
    urlTimeline: [],
    console: [],
    pageErrors: [],
    requestFailures: [],
  }

  page.on('framenavigated', (frame) => {
    if (frame === page.mainFrame()) evidence.urlTimeline.push(frame.url())
  })
  page.on('console', (message) => evidence.console.push({ type: message.type(), text: message.text() }))
  page.on('pageerror', (error) => evidence.pageErrors.push(error.message))
  page.on('requestfailed', (request) => evidence.requestFailures.push({ url: request.url(), failure: request.failure()?.errorText ?? 'unknown' }))

  await page.route('**/api/auth/session', async (route) => {
    await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'authentication_required' }) })
  })
  await page.route('**/api/auth/sign-in', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(AUTH_RESPONSE) })
  })
  await page.route('**/api/auth/sign-out', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({}) })
  })
  await page.route('https://*/rest/v1/profiles*', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([AUTHENTICATED_PROFILE]) })
  })

  await page.goto('/login?returnTo=%2F%3Ft227%3D002', { waitUntil: 'domcontentloaded' })
  await expect(page.getByText('Secure access is required')).toBeVisible()
  await expect(page.getByLabel('Email')).toBeVisible()
  await expect(page.getByLabel('Password')).toBeVisible()
  await page.getByLabel('Email').fill('t227-002@example.test')
  await page.getByLabel('Password').fill('diagnostic-password')
  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page).toHaveURL(/\?t227=002$/)
  await expect(page.getByTestId('minimal-auth-shell')).toBeVisible()
  await expect(page.getByTestId('minimal-auth-status')).toHaveText('authenticated=true')
  await expect(page.getByTestId('minimal-auth-operational')).toHaveText('operational-access=true')

  await expect(page.getByText('Create Draft Order')).toHaveCount(0)
  await expect(page.getByText('Operations Dashboard')).toHaveCount(0)
  await expect(page.locator('[aria-label="Primary navigation"]')).toHaveCount(0)
  expect(evidence.pageErrors).toEqual([])
  expect(evidence.requestFailures).toEqual([])

  await testInfo.attach('T227-002-evidence.json', { body: JSON.stringify(evidence, null, 2), contentType: 'application/json' })
})
