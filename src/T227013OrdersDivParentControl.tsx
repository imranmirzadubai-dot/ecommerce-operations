import { OrdersWorkspace } from './components/OrdersWorkspace'

export function T227013OrdersDivParentControl() {
  return (
    <main className="content">
      <div className="workspace-grid">
        <OrdersWorkspace accessToken="T227-013-DIAGNOSTIC-TOKEN" />
      </div>
    </main>
  )
}