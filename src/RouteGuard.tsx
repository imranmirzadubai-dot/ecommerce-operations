import { useEffect } from 'react'
import App from './App.tsx'
import { useAuth } from './lib/AuthContext'
import { getLoginRedirect, isProtectedPath } from './lib/routes'
import { T227004OrdersStartupControl } from './T227004OrdersStartupControl'
import { T227006StrictModeControl } from './T227006StrictModeControl'

export function RouteGuard() {
  const { authenticated, loading } = useAuth()
  const protectedPath = isProtectedPath(window.location.pathname)
  const allowed = !protectedPath || authenticated
  const params = new URLSearchParams(window.location.search)
  const diagnosticOrdersControl = params.get('t227004') === '1'
  const diagnosticStrictModeControl = params.get('t227006') === '1'

  useEffect(() => {
    if (!protectedPath || loading || authenticated) return
    window.location.replace(getLoginRedirect(window.location.pathname, window.location.search))
  }, [authenticated, loading, protectedPath])

  if (protectedPath && (loading || !allowed)) return <div aria-label="Authentication check" />
  if (diagnosticStrictModeControl) return <T227006StrictModeControl />
  if (diagnosticOrdersControl) return <T227004OrdersStartupControl />
  return <App />
}
