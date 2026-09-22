import { useEffect } from 'react'
import App from './App.tsx'
import { useAuth } from './lib/AuthContext'
import { getLoginRedirect, isProtectedPath } from './lib/routes'

export function RouteGuard() {
  const { authenticated, loading } = useAuth()
  const protectedPath = isProtectedPath(window.location.pathname)
  const allowed = !protectedPath || authenticated

  useEffect(() => {
    if (!protectedPath || loading || authenticated) return
    window.location.replace(getLoginRedirect(window.location.pathname, window.location.search))
  }, [authenticated, loading, protectedPath])

  if (protectedPath && (loading || !allowed)) return <div aria-label="Authentication check" />
  return <App />
}
