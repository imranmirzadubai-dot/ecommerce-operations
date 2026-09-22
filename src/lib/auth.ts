import { APP_ROLES, type AppRole } from './roles.ts'

export { APP_ROLES }
export type { AppRole } from './roles.ts'

export type Profile = {
  id: string
  name: string
  email: string
  role: AppRole
  active: boolean
}

export type AuthState = {
  authenticated: boolean
  userId: string | null
  profile: Profile | null
  accessToken: string | null
}

type StoredSession = {
  accessToken: string
  refreshToken: string
  expiresAt: number
  userId: string
}

type AuthConfig = { url: string; publishableKey: string }

type TokenResponse = {
  access_token: string
  refresh_token: string
  expires_in: number
  user: { id: string }
}

export class HttpError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'HttpError'
    this.status = status
  }
}

const SESSION_KEY = 'ecommerce-operations.auth.session'
const AUTH_REQUEST_TIMEOUT_MS = 8_000
const E2E = import.meta.env?.VITE_APP_ENVIRONMENT === 'e2e'

function authTrace(event: string, details: Record<string, unknown> = {}): void {
  if (E2E) console.info('[AUTH-E2E]', event, JSON.stringify(details))
}

export function hasOperationalAccess(profile: Profile | null): boolean {
  return profile?.active === true && APP_ROLES.includes(profile.role)
}

export function canAdministerUsers(profile: Profile | null): boolean {
  return profile?.active === true && profile.role === 'admin'
}

export function getAuthConfig(): AuthConfig | null {
  const url = import.meta.env.VITE_SUPABASE_URL?.trim()
  const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()
  if (!url || !publishableKey) return null
  return { url: url.replace(/\/$/, ''), publishableKey }
}

function readStoredSession(): StoredSession | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY)
    return raw ? (JSON.parse(raw) as StoredSession) : null
  } catch {
    return null
  }
}

function storeSession(session: StoredSession): void {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session))
  authTrace('store-session', { token: session.accessToken, userId: session.userId })
  authTrace('session-after-write', { stored: localStorage.getItem(SESSION_KEY), origin: window.location.origin })
}

export function clearStoredSession(): void {
  localStorage.removeItem(SESSION_KEY)
  authTrace('clear-session')
}

function clearStoredSessionIfCurrent(expectedAccessToken: string): void {
  const current = readStoredSession()
  authTrace('clear-if-current', { expectedToken: expectedAccessToken, currentToken: current?.accessToken ?? null })
  if (current?.accessToken === expectedAccessToken) clearStoredSession()
}

async function fetchWithTimeout(input: RequestInfo | URL, init: RequestInit, signal?: AbortSignal): Promise<Response> {
  if (signal?.aborted) {
    authTrace('fetch-aborted-before-start')
    throw new DOMException('The operation was aborted', 'AbortError')
  }
  const controller = new AbortController()
  const timeout = window.setTimeout(() => controller.abort(), AUTH_REQUEST_TIMEOUT_MS)
  const abort = () => controller.abort()
  signal?.addEventListener('abort', abort, { once: true })
  try {
    return await fetch(input, { ...init, signal: controller.signal })
  } finally {
    window.clearTimeout(timeout)
    signal?.removeEventListener('abort', abort)
  }
}

async function authRequest<T>(config: AuthConfig, grantType: 'password' | 'refresh_token', body: Record<string, string>, signal?: AbortSignal): Promise<T> {
  authTrace('auth-request-start', { grantType, aborted: signal?.aborted ?? false })
  let response: Response
  try {
    response = await fetchWithTimeout(`${config.url}/auth/v1/token?grant_type=${grantType}`, {
      method: 'POST',
      headers: { apikey: config.publishableKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, signal)
  } catch (error) {
    authTrace('auth-request-error', { grantType, error: error instanceof Error ? error.message : String(error), aborted: signal?.aborted ?? false })
    throw error
  }
  authTrace('auth-request-response', { grantType, status: response.status })
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { msg?: string; error_description?: string; message?: string } | null
    throw new HttpError(payload?.msg ?? payload?.error_description ?? payload?.message ?? 'Authentication request failed', response.status)
  }
  return response.json() as Promise<T>
}

async function loadProfile(config: AuthConfig, accessToken: string, userId: string, signal?: AbortSignal): Promise<Profile> {
  authTrace('profile-start', { token: accessToken, userId, aborted: signal?.aborted ?? false })
  let response: Response
  try {
    response = await fetchWithTimeout(`${config.url}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=id,name,email,role,active`, {
      headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}` },
    }, signal)
  } catch (error) {
    authTrace('profile-error', { token: accessToken, error: error instanceof Error ? error.message : String(error), aborted: signal?.aborted ?? false })
    throw error
  }
  authTrace('profile-response', { token: accessToken, status: response.status })
  if (!response.ok) throw new HttpError('Unable to load the authenticated profile', response.status)
  const rows = (await response.json()) as Profile[]
  const profile = rows[0]
  if (!profile || !profile.active) throw new Error('This account does not have an active operations profile')
  authTrace('profile-success', { token: accessToken, userId: profile.id })
  return profile
}

export async function signIn(email: string, password: string, signal?: AbortSignal): Promise<AuthState> {
  authTrace('sign-in-start', { email })
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const token = await authRequest<TokenResponse>(config, 'password', { email, password }, signal)
  const session: StoredSession = { accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: Date.now() + token.expires_in * 1000, userId: token.user.id }
  storeSession(session)
  try {
    const profile = await loadProfile(config, token.access_token, token.user.id, signal)
    authTrace('sign-in-success', { token: token.access_token, userId: token.user.id })
    return { authenticated: true, userId: token.user.id, profile, accessToken: token.access_token }
  } catch (error) {
    authTrace('sign-in-error', { token: token.access_token, error: error instanceof Error ? error.message : String(error), status: error instanceof HttpError ? error.status : null, aborted: signal?.aborted ?? false })
    if (signal?.aborted) throw error
    if (error instanceof HttpError && (error.status === 401 || error.status === 403)) {
      clearStoredSessionIfCurrent(session.accessToken)
    }
    throw error
  }
}

export async function restoreSession(signal?: AbortSignal): Promise<AuthState> {
  authTrace('restore-start', { aborted: signal?.aborted ?? false })
  const config = getAuthConfig()
  let session = readStoredSession()
  if (!config || !session) {
    authTrace('restore-empty')
    return { authenticated: false, userId: null, profile: null, accessToken: null }
  }
  const operationAccessToken = session.accessToken

  if (session.expiresAt <= Date.now() + 30_000) {
    try {
      const token = await authRequest<TokenResponse>(config, 'refresh_token', { refresh_token: session.refreshToken }, signal)
      session = { accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: Date.now() + token.expires_in * 1000, userId: token.user.id }
      storeSession(session)
    } catch (error) {
      authTrace('restore-refresh-error', { token: operationAccessToken, error: error instanceof Error ? error.message : String(error), aborted: signal?.aborted ?? false })
      if (signal?.aborted) throw error
      clearStoredSessionIfCurrent(operationAccessToken)
      return { authenticated: false, userId: null, profile: null, accessToken: null }
    }
  }

  try {
    const profile = await loadProfile(config, session.accessToken, session.userId, signal)
    authTrace('restore-success', { token: session.accessToken, userId: session.userId })
    return { authenticated: true, userId: session.userId, profile, accessToken: session.accessToken }
  } catch (error) {
    authTrace('restore-error', { token: session.accessToken, error: error instanceof Error ? error.message : String(error), status: error instanceof HttpError ? error.status : null, aborted: signal?.aborted ?? false })
    if (signal?.aborted) throw error
    if (error instanceof HttpError && (error.status === 401 || error.status === 403)) {
      clearStoredSessionIfCurrent(session.accessToken)
    }
    return { authenticated: false, userId: null, profile: null, accessToken: null }
  }
}

export async function signOut(signal?: AbortSignal): Promise<void> {
  authTrace('sign-out-start')
  const config = getAuthConfig()
  const stored = readStoredSession()
  clearStoredSession()
  if (!config || !stored) return
  await fetchWithTimeout(`${config.url}/auth/v1/logout`, {
    method: 'POST',
    headers: { apikey: config.publishableKey, Authorization: `Bearer ${stored.accessToken}` },
  }, signal).catch(() => undefined)
  authTrace('sign-out-complete', { token: stored.accessToken })
}
