import { OrdersWorkspace } from './components/OrdersWorkspace'

export function T227011OrdersGridControl() {
  return (
    <main className="content">
      <section className="workspace-grid">
        <article className="card order-card">
          <div className="section-heading"><div><span className="eyebrow">Customer / Order Core</span><h2>Create Draft Order</h2><p>Controlled sibling card matching the production workspace grid.</p></div><span className="check">Diagnostic</span></div>
          <div className="order-form"><label>Customer phone<input aria-label="Customer phone" /></label><label>Customer name<input aria-label="Customer name" /></label><label>Address<input aria-label="Address" /></label></div>
        </article>
        <OrdersWorkspace accessToken="T227-011-DIAGNOSTIC-TOKEN" />
      </section>
    </main>
  )
}
