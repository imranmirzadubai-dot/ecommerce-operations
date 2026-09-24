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
  const refreshTimer = useRef<number | null>(null)
  const operationGeneration = useRef(0)
  const operationController = useRef<AbortController | null>(null)

  const beginOperation = useCallback(() => {
    operationController.current?.abort()
    const controller = new AbortController()
    operationController.current = controller
    const generation = ++operationGeneration.current
    return { controller, generation }
  }, [])

  const beginUserOperation = useCallback(() => {
    setLoading(true)
    return beginOperation()
  }, [beginOperation])

  const isCurrentOperation = useCallback((generation: number, controller: AbortController) => (
    generation === operationGeneration.current && operationController.current === controller && !controller.signal.aborted
  ), [])

  const finishOperation = useCallback((generation: number, controller: AbortController) => {
    if (!isCurrentOperation(generation, controller)) return
    setLoading(false)
  }, [isCurrentOperation])

  const clearRefreshTimer = useCallback(() => {
    if (refreshTimer.current !== null) {
      window.clearTimeout(refreshTimer.current)
      refreshTimer.current = null
    }
  }, [])

  const refresh = useCallback(async (): Promise<AuthState> => {
    const { controller, generation } = beginUserOperation()
    try {
      const next = await restoreSession(controller.signal)
      if (isCurrentOperation(generation, controller)) setAuth(next)
      return next
    } finally {
      finishOperation(generation, controller)
    }
  }, [beginUserOperation, finishOperation, isCurrentOperation])

  useEffect(() => {
    const { controller, generation } = beginOperation()
    void restoreSession(controller.signal).then((next) => {
      if (isCurrentOperation(generation, controller)) setAuth(next)
    }).finally(() => {
      finishOperation(generation, controller)
    })
    return () => {
      controller.abort()
      if (operationController.current === controller) operationController.current = null
      clearRefreshTimer()
    }
  }, [beginOperation, clearRefreshTimer, finishOperation, isCurrentOperation])

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
    const { controller, generation } = beginOperation()
    try {
      const next = await authenticate(email, password, controller.signal)
      if (isCurrentOperation(generation, controller)) setAuth(next)
      return next
    } finally {
      finishOperation(generation, controller)
    }
  }, [beginOperation, finishOperation, isCurrentOperation])

  const signOut = useCallback(async () => {
    clearRefreshTimer()
    const { controller, generation } = beginOperation()
    try {
      await terminateSession(controller.signal)
      if (isCurrentOperation(generation, controller)) setAuth(signedOutState)
    } finally {
      finishOperation(generation, controller)
    }
  }, [beginOperation, clearRefreshTimer, finishOperation, isCurrentOperation])

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
