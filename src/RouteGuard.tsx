import { useEffect, useState } from 'react'
import App from './App.tsx'
import { PasswordRecovery } from './components/PasswordRecovery.tsx'
import { restoreSession, type AuthState } from './lib/auth'
import { getRecoveryToken } from './lib/passwordRecovery'
import { getLoginRedirect, isProtectedPath } from './lib/routes'

const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }
const AUTH_BOOTSTRAP_TIMEOUT_MS = 10_000

export function RouteGuard() {
  const passwordRecovery = getRecoveryToken() !== null
  const protectedPath = isProtectedPath(window.location.pathname)
  const [checking, setChecking] = useState(!passwordRecovery && protectedPath)
  const [allowed, setAllowed] = useState(passwordRecovery || !protectedPath)
  const [auth, setAuth] = useState<AuthState>(signedOutState)

  useEffect(() => {
    if (passwordRecovery) return
    const pathname = window.location.pathname
    if (!isProtectedPath(pathname)) return

    let cancelled = false
    let settled = false
    const timeout = window.setTimeout(() => {
      if (cancelled || settled) return
      settled = true
      setAuth(signedOutState)
      setChecking(false)
      window.location.replace(getLoginRedirect(pathname, window.location.search))
    }, AUTH_BOOTSTRAP_TIMEOUT_MS)

    restoreSession()
      .then((session) => {
        if (cancelled || settled) return
        settled = true
        setAuth(session)
        if (session.authenticated) {
          setAllowed(true)
        } else {
          window.location.replace(getLoginRedirect(pathname, window.location.search))
        }
      })
      .catch(() => {
        if (cancelled || settled) return
        settled = true
        setAuth(signedOutState)
        window.location.replace(getLoginRedirect(pathname, window.location.search))
      })
      .finally(() => {
        if (!cancelled) {
          window.clearTimeout(timeout)
          setChecking(false)
        }
      })

    return () => {
      cancelled = true
      window.clearTimeout(timeout)
    }
  }, [passwordRecovery])

  if (passwordRecovery) return <PasswordRecovery />
  if (checking) return <div className="auth-bootstrap" aria-label="Authentication check">Checking secure access…</div>
  return allowed ? <App auth={auth} onAuthChange={setAuth} /> : null
}
