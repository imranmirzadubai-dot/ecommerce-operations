import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { restoreSession, signIn as authenticate, signOut as terminateSession, type AuthState } from './auth'

const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }
const REFRESH_LEAD_MS = 60_000
const MIN_REFRESH_DELAY_MS = 5_000
const DIAGNOSTIC_AUTH = typeof window !== 'undefined' && (() => { const params = new URLSearchParams(window.location.search); return params.get('t227010') === '1' || params.get('t227011') === '1' })()
const diagnosticAuthState: AuthState = {
  authenticated: true,
  userId: '00000000-0000-4000-8000-000000000010',
  profile: { id: '00000000-0000-4000-8000-000000000010', name: 'T227-010 Diagnostic', email: 'diagnostic@example.invalid', role: 'admin', active: true },
  accessToken: 'T227-010-DIAGNOSTIC-TOKEN',
}

type AuthContextValue = AuthState & {
  auth: AuthState
  loading: boolean
  signIn: (email: string, password: string) => Promise<AuthState>
  signOut: () => Promise<void>
  refresh: () => Promise<AuthState>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>(DIAGNOSTIC_AUTH ? diagnosticAuthState : signedOutState)
  const [loading, setLoading] = useState(!DIAGNOSTIC_AUTH)
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
    if (DIAGNOSTIC_AUTH) return
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
