import { test, expect } from '@playwright/test'

test('T227-001 clean-main application startup evidence', async ({ page }, testInfo) => {
  const evidence = {
    task: 'T227-001',
    commit: process.env.GITHUB_SHA ?? 'local',
    environment: process.env.VITE_APP_ENVIRONMENT ?? process.env.NODE_ENV ?? 'unknown',
    browser: testInfo.project.name,
    url: '',
    console: [],
    pageErrors: [],
    requestFailures: [],
  }

  page.on('console', (message) => {
    evidence.console.push({ type: message.type(), text: message.text() })
  })
  page.on('pageerror', (error) => {
    evidence.pageErrors.push(error.message)
  })
  page.on('requestfailed', (request) => {
    evidence.requestFailures.push({
      method: request.method(),
      url: request.url(),
      failure: request.failure()?.errorText ?? 'unknown',
    })
  })

  await page.goto('/', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('body')).toBeVisible()
  await expect(page.getByText('E-Commerce Operations')).toBeVisible()
  await expect(page.getByText(/Secure access is required|Authenticated/)).toBeVisible()

  evidence.url = page.url()
  await testInfo.attach('T227-001-evidence.json', {
    body: JSON.stringify(evidence, null, 2),
    contentType: 'application/json',
  })

  expect(evidence.pageErrors, JSON.stringify(evidence.pageErrors)).toEqual([])
})
