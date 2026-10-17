import { OrdersWorkspace } from './components/OrdersWorkspace'

const TOKEN = 'T227-004-DIAGNOSTIC-TOKEN'

export function T227004OrdersStartupControl() {
  const params = new URLSearchParams(window.location.search)
  const enabled = params.get('orders') === 'on'

  return (
    <main className="content" data-t227004-orders={enabled ? 'on' : 'off'}>
      <section className="card">
        <span className="eyebrow">T227-004 Orders Startup Control</span>
        <h1>Orders startup isolation</h1>
        <p>Diagnostic-only control. Production bootstrap remains unchanged; the Orders workspace is explicitly toggled for comparison.</p>
        <p><strong>Orders:</strong> {enabled ? 'ON' : 'OFF'}</p>
      </section>
      {enabled && <OrdersWorkspace accessToken={TOKEN} />}
    </main>
  )
}
