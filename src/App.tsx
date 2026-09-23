import { useAuth } from './lib/AuthContext'
import { getAuthConfig, hasOperationalAccess } from './lib/auth'

export default function App() {
  const { auth, loading } = useAuth()
  const configured = getAuthConfig() !== null
  const operationalAccess = hasOperationalAccess(auth.profile)

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 720, margin: '64px auto', padding: '0 24px' }}>
      <p data-testid="auth-shell-label">T227-002 · Minimal Auth Shell</p>
      <h1>Authentication Control</h1>
      <p data-testid="auth-shell-status">
        {loading ? 'Checking the current authenticated session…' : operationalAccess ? 'Authenticated session restored.' : 'No active authenticated session.'}
      </p>
      <dl>
        <dt>Auth configuration</dt>
        <dd data-testid="auth-shell-configured">{configured ? 'configured' : 'not configured'}</dd>
        <dt>Auth loading</dt>
        <dd data-testid="auth-shell-loading">{loading ? 'true' : 'false'}</dd>
        <dt>Authenticated</dt>
        <dd data-testid="auth-shell-authenticated">{auth.authenticated ? 'true' : 'false'}</dd>
        <dt>Operational access</dt>
        <dd data-testid="auth-shell-operational">{operationalAccess ? 'true' : 'false'}</dd>
      </dl>
    </main>
  )
}
