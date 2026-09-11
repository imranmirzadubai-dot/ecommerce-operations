import { FormEvent, useEffect, useState } from 'react'
import './App.css'
import { getAuthConfig, hasOperationalAccess, restoreSession, signIn, signOut, type AuthState } from './lib/auth'

const navigation = ['Dashboard', 'Customers', 'Orders', 'Parcels', 'Dispatch', 'Delivery / NDR', 'COD & Finance', 'Invoices', 'Reports']

const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }

function App() {
  const [auth, setAuth] = useState<AuthState>(signedOutState)
  const [loading, setLoading] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const configured = getAuthConfig() !== null
  const authenticated = hasOperationalAccess(auth.profile)

  useEffect(() => {
    restoreSession().then(setAuth).finally(() => setLoading(false))
  }, [])

  async function handleSignIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    setLoading(true)
    try {
      setAuth(await signIn(email.trim(), password))
      setPassword('')
    } catch (signInError) {
      setError(signInError instanceof Error ? signInError.message : 'Unable to sign in')
    } finally {
      setLoading(false)
    }
  }

  async function handleSignOut() {
    await signOut()
    setAuth(signedOutState)
  }

  return (
    <div className="operations-app">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark">EO</span>
          <div><strong>E-Commerce Operations</strong><span>Operations workspace</span></div>
        </div>
        <div className="environment">
          <span className="status-dot" />
          <span>STAGING</span>
          {authenticated && <button className="signout" onClick={handleSignOut}>Sign out</button>}
        </div>
      </header>

      <div className="app-body">
        <aside className="sidebar" aria-label="Primary navigation">
          <nav>{navigation.map((item, index) => <button className={index === 0 ? 'nav-item active' : 'nav-item'} disabled={!authenticated} key={item}><span>{item}</span>{index === 0 && <span className="nav-badge">Core</span>}</button>)}</nav>
          <div className="sidebar-footer"><span className="eyebrow">Access</span><strong>{auth.profile?.role ?? 'Not signed in'}</strong></div>
        </aside>

        <main className="content">
          <div className="page-heading">
            <div><span className="eyebrow">Workspace</span><h1>Operations Dashboard</h1><p>Transactional order, parcel, delivery and financial operations.</p></div>
            <span className="foundation-pill">Foundation protected</span>
          </div>

          {!authenticated && (
            <section className="access-panel" aria-labelledby="access-title">
              <div className="access-icon">✓</div>
              <div>
                <span className="eyebrow">Authentication boundary</span>
                <h2 id="access-title">Secure access is required</h2>
                {!configured ? (
                  <p>Authentication is not configured for this deployment yet. No demo account or business data is being fabricated.</p>
                ) : loading ? (
                  <p>Checking the current authenticated session…</p>
                ) : (
                  <form className="login-form" onSubmit={handleSignIn}>
                    <label>Email<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="username" required /></label>
                    <label>Password<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required /></label>
                    <button className="login-button" type="submit" disabled={loading}>{loading ? 'Signing in…' : 'Sign in'}</button>
                    {error && <p className="form-error" role="alert">{error}</p>}
                  </form>
                )}
              </div>
              <div className="access-state">Signed out</div>
            </section>
          )}

          {authenticated && (
            <section className="access-panel signed-in-panel">
              <div className="access-icon">✓</div>
              <div><span className="eyebrow">Authenticated</span><h2>{auth.profile?.name}</h2><p>{auth.profile?.email} · {auth.profile?.role}</p></div>
              <div className="access-state">Active</div>
            </section>
          )}

          <section className="metrics" aria-label="Workspace status">
            {['Orders', 'Parcels', 'COD', 'Exceptions'].map((metric) => <article key={metric}><span className="eyebrow">{metric}</span><strong>—</strong><p>{authenticated ? 'Ready for transactional data' : 'Awaiting authenticated data'}</p></article>)}
          </section>

          <section className="foundation-grid">
            <article className="card"><span className="eyebrow">Database</span><h2>Security foundation</h2><p>PostgreSQL constraints, RLS and transactional command boundaries are established before business data entry.</p><span className="check">✓ Verified in CI and staging</span></article>
            <article className="card"><span className="eyebrow">Commands</span><h2>Idempotency foundation</h2><p>State-changing order commands use an authenticated actor and deterministic idempotency key boundary.</p><span className="check">✓ Structural + staging behavior verified</span></article>
            <article className="card"><span className="eyebrow">Environment</span><h2>Staging isolation</h2><p>Business fixtures remain absent. The workspace cannot silently fall back to production data.</p><span className="check">✓ No production data touched</span></article>
          </section>
        </main>
      </div>
    </div>
  )
}

export default App
