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

type AuthConfig = { url: string; publishableKey: string }

type AuthResponse = {
  accessToken: string
  userId: string
}

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

const LEGACY_SESSION_KEY = 'ecommerce-operations.auth.session'

export function clearStoredSession(): void {
  try {
    localStorage.removeItem(LEGACY_SESSION_KEY)
  } catch {
    // Browser storage may be unavailable; authentication does not depend on it.
  }
}

async function fetchWithTimeout(input: RequestInfo | URL, init: RequestInit, signal?: AbortSignal, credentials: RequestCredentials = 'include'): Promise<Response> {
  const controller = new AbortController()
  const abort = () => controller.abort(signal?.reason)
  if (signal?.aborted) abort()
  else signal?.addEventListener('abort', abort, { once: true })
  const timeout = window.setTimeout(() => controller.abort(), AUTH_REQUEST_TIMEOUT_MS)
  try {
    return await fetch(input, { ...init, signal: controller.signal, credentials })
  } finally {
    window.clearTimeout(timeout)
    signal?.removeEventListener('abort', abort)
  }
}

async function authEndpoint<T>(path: string, init: RequestInit, signal?: AbortSignal): Promise<T> {
  let response: Response
  try {
    response = await fetchWithTimeout(path, init, signal)
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('Authentication request timed out', { cause: error })
    }
    throw error
  }

  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { error?: string; message?: string } | null
    throw new Error(payload?.message ?? payload?.error ?? 'Authentication request failed')
  }
  return response.json() as Promise<T>
}

async function loadProfile(config: AuthConfig, accessToken: string, userId: string, signal?: AbortSignal): Promise<Profile> {
  let response: Response
  try {
    response = await fetchWithTimeout(`${config.url}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=id,name,email,role,active`, {
      headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}` },
    }, signal, 'omit')
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('Authenticated profile request timed out', { cause: error })
    }
    throw error
  }
  if (!response.ok) throw new Error('Unable to load the authenticated profile')
  const rows = (await response.json()) as Profile[]
  const profile = rows[0]
  if (!profile || !profile.active) throw new Error('This account does not have an active operations profile')
  return profile
}

export async function signIn(email: string, password: string, signal?: AbortSignal): Promise<AuthState> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const session = await authEndpoint<AuthResponse>('/api/auth/sign-in', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  }, signal)
  try {
    const profile = await loadProfile(config, session.accessToken, session.userId, signal)
    return { authenticated: true, userId: session.userId, profile, accessToken: session.accessToken }
  } catch (error) {
    await authEndpoint('/api/auth/sign-out', { method: 'POST' }).catch(() => undefined)
    throw error
  }
}

export async function restoreSession(signal?: AbortSignal): Promise<AuthState> {
  clearStoredSession()
  const config = getAuthConfig()
  if (!config) return { authenticated: false, userId: null, profile: null, accessToken: null }

  let session: AuthResponse
  try {
    session = await authEndpoint<AuthResponse>('/api/auth/session', { method: 'GET' }, signal)
  } catch (error) {
    if (error instanceof Error && error.message === 'authentication_required') {
      return { authenticated: false, userId: null, profile: null, accessToken: null }
    }
    return { authenticated: false, userId: null, profile: null, accessToken: null }
  }

  try {
    const profile = await loadProfile(config, session.accessToken, session.userId, signal)
    return { authenticated: true, userId: session.userId, profile, accessToken: session.accessToken }
  } catch {
    await authEndpoint('/api/auth/sign-out', { method: 'POST' }).catch(() => undefined)
    return { authenticated: false, userId: null, profile: null, accessToken: null }
  }
}

export async function signOut(signal?: AbortSignal): Promise<void> {
  await authEndpoint('/api/auth/sign-out', { method: 'POST' }, signal).catch(() => undefined)
}
