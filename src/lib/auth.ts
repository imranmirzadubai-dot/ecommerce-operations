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

const SESSION_KEY = 'ecommerce-operations.auth.session'
const AUTH_REQUEST_TIMEOUT_MS = 8_000

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
}

export function clearStoredSession(): void {
  localStorage.removeItem(SESSION_KEY)
}

async function fetchWithTimeout(input: RequestInfo | URL, init: RequestInit): Promise<Response> {
  const controller = new AbortController()
  const timeout = window.setTimeout(() => controller.abort(), AUTH_REQUEST_TIMEOUT_MS)
  try {
    return await fetch(input, { ...init, signal: controller.signal })
  } finally {
    window.clearTimeout(timeout)
  }
}

async function authRequest<T>(config: AuthConfig, grantType: 'password' | 'refresh_token', body: Record<string, string>): Promise<T> {
  let response: Response
  try {
    response = await fetchWithTimeout(`${config.url}/auth/v1/token?grant_type=${grantType}`, {
      method: 'POST',
      headers: { apikey: config.publishableKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw new Error('Authentication request timed out')
    throw error
  }
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { msg?: string; error_description?: string; message?: string } | null
    throw new Error(payload?.msg ?? payload?.error_description ?? payload?.message ?? 'Authentication request failed')
  }
  return response.json() as Promise<T>
}

async function loadProfile(config: AuthConfig, accessToken: string, userId: string): Promise<Profile> {
  let response: Response
  try {
    response = await fetchWithTimeout(`${config.url}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=id,name,email,role,active`, {
      headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}` },
    })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw new Error('Authenticated profile request timed out')
    throw error
  }
  if (!response.ok) throw new Error('Unable to load the authenticated profile')
  const rows = (await response.json()) as Profile[]
  const profile = rows[0]
  if (!profile || !profile.active) throw new Error('This account does not have an active operations profile')
  return profile
}

export async function signIn(email: string, password: string): Promise<AuthState> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const token = await authRequest<TokenResponse>(config, 'password', { email, password })
  storeSession({ accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: Date.now() + token.expires_in * 1000, userId: token.user.id })
  try {
    const profile = await loadProfile(config, token.access_token, token.user.id)
    return { authenticated: true, userId: token.user.id, profile, accessToken: token.access_token }
  } catch (error) {
    clearStoredSession()
    throw error
  }
}

export async function restoreSession(): Promise<AuthState> {
  const config = getAuthConfig()
  let session = readStoredSession()
  if (!config || !session) return { authenticated: false, userId: null, profile: null, accessToken: null }

  if (session.expiresAt <= Date.now() + 30_000) {
    try {
      const token = await authRequest<TokenResponse>(config, 'refresh_token', { refresh_token: session.refreshToken })
      session = { accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: Date.now() + token.expires_in * 1000, userId: token.user.id }
      storeSession(session)
    } catch {
      clearStoredSession()
      return { authenticated: false, userId: null, profile: null, accessToken: null }
    }
  }

  try {
    const profile = await loadProfile(config, session.accessToken, session.userId)
    return { authenticated: true, userId: session.userId, profile, accessToken: session.accessToken }
  } catch {
    clearStoredSession()
    return { authenticated: false, userId: null, profile: null, accessToken: null }
  }
}

export async function signOut(): Promise<void> {
  const config = getAuthConfig()
  const stored = readStoredSession()
  clearStoredSession()
  if (!config || !stored) return
  await fetchWithTimeout(`${config.url}/auth/v1/logout`, {
    method: 'POST',
    headers: { apikey: config.publishableKey, Authorization: `Bearer ${stored.accessToken}` },
  }).catch(() => undefined)
}
