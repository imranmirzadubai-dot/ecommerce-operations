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

type AuthOperation = {
  myGen: number
  signal: AbortSignal
  abort: () => void
  isCurrent: () => boolean
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>(signedOutState)
  const [loading, setLoading] = useState(true)
  const refreshTimer = useRef<number | null>(null)
  const generationRef = useRef(0)
  const controllerRef = useRef<AbortController | null>(null)

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
      setAuth(next)
      return next
    } catch (error) {
      if (op.signal.aborted || !op.isCurrent()) return signedOutState
      setAuth(signedOutState)
      throw error
    }
  }, [startOperation])

  useEffect(() => {
    const op = startOperation()
    void restoreSession(op.signal).then((next) => {
      if (op.isCurrent()) setAuth(next)
    }).catch((error: unknown) => {
      if (!op.signal.aborted && op.isCurrent()) setAuth(signedOutState)
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
    try {
      const next = await authenticate(email, password, op.signal)
      if (!op.isCurrent()) return next
      setAuth(next)
      return next
    } catch (error) {
      if (op.signal.aborted || !op.isCurrent()) return signedOutState
      setAuth(signedOutState)
      throw error
    }
  }, [startOperation])

  const signOut = useCallback(async () => {
    clearRefreshTimer()
    const op = startOperation()
    await terminateSession(op.signal)
    if (op.isCurrent()) setAuth(signedOutState)
  }, [clearRefreshTimer, startOperation])

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
