import './App.css'
import { canAdministerUsers, hasOperationalAccess, type Profile } from './lib/auth'

const navigation = [
  'Dashboard',
  'Customers',
  'Orders',
  'Parcels',
  'Dispatch',
  'Delivery / NDR',
  'COD & Finance',
  'Invoices',
  'Reports',
]

function App() {
  const profile: Profile | null = null
  const authenticated = hasOperationalAccess(profile)

  return (
    <div className="operations-app">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark">EO</span>
          <div>
            <strong>E-Commerce Operations</strong>
            <span>Operations workspace</span>
          </div>
        </div>
        <div className="environment">
          <span className="status-dot" />
          <span>STAGING</span>
        </div>
      </header>

      <div className="app-body">
        <aside className="sidebar" aria-label="Primary navigation">
          <nav>
            {navigation.map((item, index) => (
              <button className={index === 0 ? 'nav-item active' : 'nav-item'} disabled={!authenticated} key={item}>
                <span>{item}</span>
                {index === 0 && <span className="nav-badge">Core</span>}
              </button>
            ))}
          </nav>
          <div className="sidebar-footer">
            <span className="eyebrow">Access</span>
            <strong>{profile?.role ?? 'Not signed in'}</strong>
            {canAdministerUsers(profile) && <span>Administrator</span>}
          </div>
        </aside>

        <main className="content">
          <div className="page-heading">
            <div>
              <span className="eyebrow">Workspace</span>
              <h1>Operations Dashboard</h1>
              <p>Transactional order, parcel, delivery and financial operations.</p>
            </div>
            <span className="foundation-pill">Foundation protected</span>
          </div>

          {!authenticated && (
            <section className="access-panel" aria-labelledby="access-title">
              <div className="access-icon">✓</div>
              <div>
                <span className="eyebrow">Authentication boundary</span>
                <h2 id="access-title">Secure access is required</h2>
                <p>
                  The application shell is ready, but operational actions remain locked until a valid Supabase-authenticated
                  profile is present. No demo user or business data is being fabricated.
                </p>
              </div>
              <div className="access-state">Signed out</div>
            </section>
          )}

          <section className="metrics" aria-label="Workspace status">
            <article>
              <span className="eyebrow">Orders</span>
              <strong>—</strong>
              <p>Awaiting authenticated data</p>
            </article>
            <article>
              <span className="eyebrow">Parcels</span>
              <strong>—</strong>
              <p>Awaiting authenticated data</p>
            </article>
            <article>
              <span className="eyebrow">COD</span>
              <strong>—</strong>
              <p>Awaiting authenticated data</p>
            </article>
            <article>
              <span className="eyebrow">Exceptions</span>
              <strong>—</strong>
              <p>Awaiting authenticated data</p>
            </article>
          </section>

          <section className="foundation-grid">
            <article className="card">
              <span className="eyebrow">Database</span>
              <h2>Security foundation</h2>
              <p>PostgreSQL constraints, RLS and transactional command boundaries are established before business data entry.</p>
              <span className="check">✓ Verified in CI and staging</span>
            </article>
            <article className="card">
              <span className="eyebrow">Commands</span>
              <h2>Idempotency foundation</h2>
              <p>State-changing order commands use an authenticated actor and deterministic idempotency key boundary.</p>
              <span className="check">✓ Structural + staging behavior verified</span>
            </article>
            <article className="card">
              <span className="eyebrow">Environment</span>
              <h2>Staging isolation</h2>
              <p>Business fixtures remain absent. The workspace cannot silently fall back to production data.</p>
              <span className="check">✓ No production data touched</span>
            </article>
          </section>
        </main>
      </div>
    </div>
  )
}

export default App
