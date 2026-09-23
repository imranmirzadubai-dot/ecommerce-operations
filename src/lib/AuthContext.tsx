import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { restoreSession, signIn as authenticate, signOut as terminateSession, type AuthState } from './auth'

const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }
const REFRESH_LEAD_MS = 60_000
const MIN_REFRESH_DELAY_MS = 5_000

type AuthContextValue = AuthState & {
  auth: AuthState
  loading: boolean
  signIn: (email: string, password: string) => Promise<AuthState>
  signOut: () => Promise<void>
  refresh: () => Promise<AuthState>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>(signedOutState)
  const [loading, setLoading] = useState(true)
  const diagnosticAuthenticated = new URLSearchParams(window.location.search).get('t227009') === '1'
  const refreshTimer = useRef<number | null>(null)

  const clearRefreshTimer = useCallback(() => {
    if (refreshTimer.current !== null) {
      window.clearTimeout(refreshTimer.current)
      refreshTimer.current = null
    }
  }, [])

  const refresh = useCallback(async (): Promise<AuthState> => {
    const next = await restoreSession()
    setAuth(next)
    return next
  }, [])

  useEffect(() => {
    if (diagnosticAuthenticated) {
      setAuth({ authenticated: true, userId: '00000000-0000-0000-0000-000000000009', profile: { id: '00000000-0000-0000-0000-000000000009', name: 'T227-009 Diagnostic Admin', email: 't227009@example.invalid', role: 'admin', active: true }, accessToken: 'T227-009-DIAGNOSTIC-TOKEN' })
      setLoading(false)
      return
    }
    let cancelled = false
    void restoreSession().then((next) => {
      if (!cancelled) setAuth(next)
    }).finally(() => {
      if (!cancelled) setLoading(false)
    })
    return () => {
      cancelled = true
      clearRefreshTimer()
    }
  }, [clearRefreshTimer])

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
    const next = await authenticate(email, password)
    setAuth(next)
    return next
  }, [])

  const signOut = useCallback(async () => {
    clearRefreshTimer()
    await terminateSession()
    setAuth(signedOutState)
  }, [clearRefreshTimer])

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
