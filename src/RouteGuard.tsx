import { useEffect, useState } from 'react'
import App from './App.tsx'
import { restoreSession, type AuthState } from './lib/auth'
import { getLoginRedirect, isProtectedPath } from './lib/routes'

const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }

export function RouteGuard() {
  const protectedPath = isProtectedPath(window.location.pathname)
  const [checking, setChecking] = useState(protectedPath)
  const [allowed, setAllowed] = useState(!protectedPath)
  const [auth, setAuth] = useState<AuthState>(signedOutState)

  useEffect(() => {
    const pathname = window.location.pathname
    if (!isProtectedPath(pathname)) return

    let cancelled = false
    restoreSession()
      .then((session) => {
        if (cancelled) return
        setAuth(session)
        if (session.authenticated) {
          setAllowed(true)
        } else {
          window.location.replace(getLoginRedirect(pathname, window.location.search))
        }
      })
      .catch(() => {
        if (cancelled) return
        setAuth(signedOutState)
        window.location.replace(getLoginRedirect(pathname, window.location.search))
      })
      .finally(() => {
        if (!cancelled) setChecking(false)
      })

    return () => { cancelled = true }
  }, [])

  if (checking) return <div className="auth-bootstrap" aria-label="Authentication check">Checking secure access…</div>
  return allowed ? <App auth={auth} onAuthChange={setAuth} /> : null
}
