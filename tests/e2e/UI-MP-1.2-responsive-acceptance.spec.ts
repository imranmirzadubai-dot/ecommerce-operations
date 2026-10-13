import { test, expect } from '@playwright/test'

const PROFILE = {
  id: 'ui-responsive-acceptance-user',
  name: 'UI Responsive Acceptance',
  email: 'ui-responsive@example.test',
  role: 'admin',
  active: true,
}

const AUTH_RESPONSE = {
  accessToken: 'e30.invalid.ui-responsive-token',
  userId: PROFILE.id,
}

const VIEWPORTS = [
  { name: 'mobile-390x844', width: 390, height: 844 },
  { name: 'mobile-430x932', width: 430, height: 932 },
  { name: 'tablet-768x1024', width: 768, height: 1024 },
  { name: 'desktop-1280x900', width: 1280, height: 900 },
] as const

for (const viewport of VIEWPORTS) {
  test(`UI-MP-1.2 responsive acceptance at ${viewport.name}`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height })

    let authenticated = false
    const pageErrors: string[] = []

    page.on('pageerror', (error) => pageErrors.push(error.message))

    // Keep the test hermetic: no live auth, API, or database calls.
    await page.route('**/api/**', async (route) => {
      const pathname = new URL(route.request().url()).pathname
      if (pathname.endsWith('/auth/session')) {
        await route.fulfill({
          status: authenticated ? 200 : 401,
          contentType: 'application/json',
          body: JSON.stringify(authenticated ? AUTH_RESPONSE : { error: 'authentication_required' }),
        })
        return
      }
      if (pathname.endsWith('/auth/sign-in')) {
        authenticated = true
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(AUTH_RESPONSE) })
        return
      }
      if (pathname.endsWith('/auth/sign-out')) {
        authenticated = false
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({}) })
        return
      }
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: { 'X-Has-More': 'false' },
        body: JSON.stringify([]),
      })
    })
    // Register the broad fallback first; Playwright gives later routes precedence.
    await page.route('**/rest/v1/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([]) })
    })
    await page.route('**/rest/v1/profiles*', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([PROFILE]) })
    })

    await page.goto('/login?returnTo=%2F%3FuiResponsiveAcceptance%3D1', { waitUntil: 'domcontentloaded' })
    await expect(page.getByText('Secure access is required')).toBeVisible()
    await page.getByLabel('Email').fill(PROFILE.email)
    await page.getByLabel('Password').fill('diagnostic-password')
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\?uiResponsiveAcceptance=1$/)
    await expect(page.getByText('Operations Dashboard', { exact: true })).toBeVisible()

    await page.evaluate(() => document.fonts.ready)
    await page.waitForTimeout(100)

    const layout = await page.evaluate(() => {
      const root = document.documentElement
      const body = document.body
      const visibleControls = Array.from(document.querySelectorAll<HTMLElement>(
        'button, input, select, textarea, [role="button"], a',
      )).filter((element) => {
        const rect = element.getBoundingClientRect()
        const style = getComputedStyle(element)
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none'
      })
      return {
        viewport: { width: window.innerWidth, height: window.innerHeight },
        document: { scrollWidth: root.scrollWidth, clientWidth: root.clientWidth },
        body: { scrollWidth: body.scrollWidth, clientWidth: body.clientWidth },
        visibleControlCount: visibleControls.length,
        controlsBelow44px: visibleControls.filter((element) => element.getBoundingClientRect().height < 44).length,
      }
    })

    expect(layout.document.scrollWidth, 'document must not overflow horizontally').toBeLessThanOrEqual(viewport.width)
    expect(layout.body.scrollWidth, 'body must not overflow horizontally').toBeLessThanOrEqual(viewport.width)
    expect(pageErrors, 'no uncaught browser errors').toEqual([])

    await testInfo.attach(`ui-responsive-${viewport.name}.json`, {
      body: JSON.stringify({ task: 'UI-MP-1.2', viewport: viewport.name, layout, pageErrors }, null, 2),
      contentType: 'application/json',
    })
    await testInfo.attach(`ui-responsive-${viewport.name}.png`, {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    })
  })
}
