import './App.css'
import { OrdersWorkspace } from './components/OrdersWorkspace'
import { CustomerHistoryWorkspace } from './components/CustomerHistoryWorkspace'
import { DispatchScanWorkspace } from './components/DispatchScanWorkspace'
import { RtoScanWorkspace } from './components/RtoScanWorkspace'

const TOKEN = 'T227-003-DIAGNOSTIC-TOKEN'
type Workspace = 'none' | 'customers' | 'dispatch' | 'rto' | 'orders'

function getWorkspace(): Workspace {
  const value = new URLSearchParams(window.location.search).get('workspace')
  return value === 'customers' || value === 'dispatch' || value === 'rto' || value === 'orders' ? value : 'none'
}

export default function App() {
  const workspace = getWorkspace()
  return (
    <main className="content" data-t227003-workspace={workspace}>
      <section className="card">
        <span className="eyebrow">T227-003 Workspace Isolation</span>
        <h1>Controlled workspace mount</h1>
        <p>Diagnostic-only shell. Authentication is intentionally held outside this matrix; every workspace receives the same sentinel token.</p>
        <p><strong>Selected workspace:</strong> {workspace}</p>
      </section>
      {workspace === 'customers' && <CustomerHistoryWorkspace accessToken={TOKEN} />}
      {workspace === 'dispatch' && <DispatchScanWorkspace accessToken={TOKEN} />}
      {workspace === 'rto' && <RtoScanWorkspace accessToken={TOKEN} />}
      {workspace === 'orders' && <OrdersWorkspace accessToken={TOKEN} />}
    </main>
  )
}
