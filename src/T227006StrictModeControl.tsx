import { OrdersWorkspace } from './components/OrdersWorkspace'

const TOKEN = 'T227-006-DIAGNOSTIC-TOKEN'

export function T227006StrictModeControl() {
  const params = new URLSearchParams(window.location.search)
  const strictMode = params.get('strict') !== 'off'

  return (
    <main className="content" data-t227006-strict={strictMode ? 'on' : 'off'}>
      <section className="card">
        <span className="eyebrow">T227-006 StrictMode / Layout-Effect Comparison</span>
        <h1>Orders lifecycle diagnostic</h1>
        <p>Diagnostic-only control. Production bootstrap is unchanged unless the explicit T227-006 query is present.</p>
        <p><strong>React StrictMode:</strong> {strictMode ? 'ON' : 'OFF'}</p>
      </section>
      <OrdersWorkspace accessToken={TOKEN} />
    </main>
  )
}
