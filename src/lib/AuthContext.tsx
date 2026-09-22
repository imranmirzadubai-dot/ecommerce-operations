import { createContext, useCallback, useContext, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { restoreSession, signIn as authenticate, signOut as terminateSession, type AuthState } from './auth'

const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }
const REFRESH_LEAD_MS = 60_000
const MIN_REFRESH_DELAY_MS = 5_000
const E2E = import.meta.env?.VITE_APP_ENVIRONMENT === 'e2e'

type AuthContextValue = AuthState & {
  auth: AuthState
  loading: boolean
  signIn: (email: string, password: string) => Promise<AuthState>
  signOut: () => Promise<void>
  refresh: () => Promise<AuthState>
}

const AuthContext = createContext<AuthContextValue | null>(null)

type AuthOperation = {
  myGen: number
  signal: AbortSignal
  abort: () => void
  isCurrent: () => boolean
}

function authStateTrace(event: string, auth: AuthState, details: Record<string, unknown> = {}): void {
  if (!E2E) return
  console.info('[AUTH-STATE]', event, JSON.stringify({ authenticated: auth.authenticated, userId: auth.userId, hasProfile: Boolean(auth.profile), role: auth.profile?.role ?? null, active: auth.profile?.active ?? null, hasAccessToken: Boolean(auth.accessToken), ...details }))
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const instanceId = useRef(crypto.randomUUID()).current
  console.log('[AUTH_EVENT] provider_mount', instanceId)
  const [auth, setAuth] = useState<AuthState>(signedOutState)
  const [loading, setLoading] = useState(true)
  const refreshTimer = useRef<number | null>(null)
  const generationRef = useRef(0)
  const controllerRef = useRef<AbortController | null>(null)

  useEffect(() => {
    authStateTrace('commit', auth, { loading })
  }, [auth, loading])

  const startOperation = useCallback((): AuthOperation => {
    generationRef.current += 1
    const myGen = generationRef.current
    controllerRef.current?.abort()
    const controller = new AbortController()
    controllerRef.current = controller
    return {
      myGen,
      signal: controller.signal,
      abort: () => controller.abort(),
      isCurrent: () => generationRef.current === myGen,
    }
  }, [])

  const clearRefreshTimer = useCallback(() => {
    if (refreshTimer.current !== null) {
      window.clearTimeout(refreshTimer.current)
      refreshTimer.current = null
    }
  }, [])

  const refresh = useCallback(async (): Promise<AuthState> => {
    const op = startOperation()
    try {
      const next = await restoreSession(op.signal)
      if (!op.isCurrent()) return next
      authStateTrace('refresh-set-auth', next, { generation: op.myGen })
      setAuth(next)
      return next
    } catch (error) {
      if (op.signal.aborted || !op.isCurrent()) return signedOutState
      authStateTrace('refresh-error-set-signed-out', signedOutState, { generation: op.myGen, error: error instanceof Error ? error.message : String(error) })
      setAuth(signedOutState)
      throw error
    }
  }, [startOperation])

  useLayoutEffect(() => {
    const op = startOperation()
    authStateTrace('restore-start', signedOutState, { generation: op.myGen })
    void restoreSession(op.signal).then((next) => {
      if (op.isCurrent()) {
        authStateTrace('restore-set-auth', next, { generation: op.myGen })
        setAuth(next)
      } else {
        authStateTrace('restore-stale-result', next, { generation: op.myGen })
      }
    }).catch((error: unknown) => {
      if (!op.signal.aborted && op.isCurrent()) {
        authStateTrace('restore-error-set-signed-out', signedOutState, { generation: op.myGen, error: error instanceof Error ? error.message : String(error) })
        setAuth(signedOutState)
      }
      if (!op.signal.aborted) console.error(error)
    }).finally(() => {
      if (op.isCurrent()) setLoading(false)
    })
    return () => {
      op.abort()
      clearRefreshTimer()
    }
  }, [clearRefreshTimer, startOperation])

  useEffect(() => {
    clearRefreshTimer()
    if (!auth.authenticated || !auth.accessToken) return

    const raw = localStorage.getItem('ecommerce-operations.auth.session')
    if (!raw) return
    try {
      const session = JSON.parse(raw) as { expiresAt?: number }
      if (typeof session.expiresAt !== 'number') return
      const delay = Math.max(MIN_REFRESH_DELAY_MS, session.expiresAt - Date.now() - REFRESH_LEAD_MS)
      refreshTimer.current = window.setTimeout(() => {
        void refresh()
      }, delay)
    } catch {
      // Invalid storage is handled by restoreSession; no timer is scheduled.
    }

    return clearRefreshTimer
  }, [auth.authenticated, auth.accessToken, clearRefreshTimer, refresh])

  const signIn = useCallback(async (email: string, password: string) => {
    const op = startOperation()
    authStateTrace('sign-in-start', auth, { generation: op.myGen })
    try {
      const next = await authenticate(email, password, op.signal)
      authStateTrace('sign-in-returned', next, { generation: op.myGen, current: op.isCurrent(), storedSession: localStorage.getItem('ecommerce-operations.auth.session') })
      if (!op.isCurrent()) return next
      authStateTrace('set-auth', next, { generation: op.myGen, current: op.isCurrent() })
      setAuth(next)
      setLoading(false)
      return next
    } catch (error) {
      if (op.signal.aborted || !op.isCurrent()) return signedOutState
      authStateTrace('sign-in-error-set-signed-out', signedOutState, { generation: op.myGen, error: error instanceof Error ? error.message : String(error) })
      setAuth(signedOutState)
      setLoading(false)
      throw error
    }
  }, [startOperation, auth])

  const signOut = useCallback(async () => {
    clearRefreshTimer()
    const op = startOperation()
    authStateTrace('sign-out-start', auth, { generation: op.myGen })
    await terminateSession(op.signal)
    if (op.isCurrent()) {
      authStateTrace('set-auth-signed-out', signedOutState, { generation: op.myGen })
      setAuth(signedOutState)
    }
  }, [auth, clearRefreshTimer, startOperation])

  const value = useMemo<AuthContextValue>(() => ({
    ...auth,
    auth,
    loading,
    signIn,
    signOut,
    refresh,
  }), [auth, loading, refresh, signIn, signOut])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used within AuthProvider')
  return context
}
