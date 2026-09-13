import { useEffect, useState } from 'react'
import App from './App.tsx'
import { restoreSession } from './lib/auth'
import { getLoginRedirect, isProtectedPath } from './lib/routes'

export function RouteGuard() {
  const [checking, setChecking] = useState(() => isProtectedPath(window.location.pathname))
  const [allowed, setAllowed] = useState(() => !isProtectedPath(window.location.pathname))

  useEffect(() => {
    const pathname = window.location.pathname
    if (!isProtectedPath(pathname)) return

    let cancelled = false
    restoreSession().then((session) => {
      if (cancelled) return
      if (session.authenticated) {
        setAllowed(true)
      } else {
        window.location.replace(getLoginRedirect(pathname, window.location.search))
      }
      setChecking(false)
    })
    return () => { cancelled = true }
  }, [])

  if (checking) return <div aria-label="Authentication check" />
  return allowed ? <App /> : null
}
