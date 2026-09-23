import { useEffect } from 'react'
import App from './App.tsx'
import { useAuth } from './lib/AuthContext'
import { getLoginRedirect, getPostLoginPath, isProtectedPath } from './lib/routes'

export function RouteGuard() {
  const { authenticated, loading, auth } = useAuth()
  const protectedPath = isProtectedPath(window.location.pathname)
  const allowed = !protectedPath || authenticated
  const e2eShell = import.meta.env?.VITE_APP_ENVIRONMENT === 'e2e' && new URLSearchParams(window.location.search).get('e2eShell') === '1'

  useEffect(() => {
    if (!protectedPath || loading || authenticated) return
    window.location.replace(getLoginRedirect(window.location.pathname, window.location.search))
  }, [authenticated, loading, protectedPath])

  useEffect(() => {
    if (!e2eShell || !authenticated || !auth.profile || loading) return
    console.info('[E2E-SHELL-NAV-EFFECT]', JSON.stringify({ pathname: window.location.pathname, authenticated, loading, profile: auth.profile }))
    if (window.location.pathname === '/login') window.location.replace(getPostLoginPath(window.location.search))
  }, [authenticated, auth.profile, e2eShell, loading])

  if (protectedPath && (loading || !allowed)) return <div aria-label="Authentication check" />
  if (e2eShell) {
    return <main data-e2e-shell="authenticated" data-auth-state={authenticated ? 'authenticated' : 'unauthenticated'}>{authenticated ? <h1>E2E authenticated shell</h1> : <h1>E2E unauthenticated shell</h1>}</main>
  }
  return <App />
}
