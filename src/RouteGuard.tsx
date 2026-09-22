import { useEffect, useState } from 'react'
import App from './App.tsx'
import { useAuth } from './lib/AuthContext'
import { getLoginRedirect, isProtectedPath } from './lib/routes'

export function RouteGuard() {
  const { authenticated, loading } = useAuth()
  const protectedPath = isProtectedPath(window.location.pathname)
  const [allowed, setAllowed] = useState(() => !protectedPath)

  useEffect(() => {
    if (!protectedPath || loading) return
    if (authenticated) {
      setAllowed(true)
      return
    }
    window.location.replace(getLoginRedirect(window.location.pathname, window.location.search))
  }, [authenticated, loading, protectedPath])

  if (protectedPath && (loading || !allowed)) return <div aria-label="Authentication check" />
  return <App />
}
