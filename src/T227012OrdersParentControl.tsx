import { OrdersWorkspace } from './components/OrdersWorkspace'

export function T227012OrdersParentControl() {
  return (
    <main className="content">
      <section className="workspace-grid">
        <OrdersWorkspace accessToken="T227-012-DIAGNOSTIC-TOKEN" />
      </section>
    </main>
  )
}
