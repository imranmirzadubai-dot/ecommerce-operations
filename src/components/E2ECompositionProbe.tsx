import { useEffect } from 'react'
import { useAuth } from '../lib/AuthContext'
import type { AuthState } from '../lib/auth'
import { OrdersWorkspace } from './OrdersWorkspace'
import { InvoicePrintWorkspace } from './InvoicePrintWorkspace'
import { DispatchScanWorkspace } from './DispatchScanWorkspace'
import { RtoScanWorkspace } from './RtoScanWorkspace'
import { CustomerHistoryWorkspace } from './CustomerHistoryWorkspace'
import { AdminUserControls } from './AdminUserControls'
import { OrderExport } from './OrderExport'

const components = [
  'OrdersWorkspace',
  'InvoicePrintWorkspace',
  'DispatchScanWorkspace',
  'RtoScanWorkspace',
  'CustomerHistoryWorkspace',
  'AdminUserControls',
  'OrderExport',
] as const

type ComponentName = (typeof components)[number]
type Profile = NonNullable<AuthState['profile']>

function renderComponent(name: ComponentName, accessToken: string, profile: Profile | null) {
  const props = { accessToken }
  switch (name) {
    case 'OrdersWorkspace': return <OrdersWorkspace {...props} />
    case 'InvoicePrintWorkspace': return <InvoicePrintWorkspace {...props} />
    case 'DispatchScanWorkspace': return <DispatchScanWorkspace {...props} />
    case 'RtoScanWorkspace': return <RtoScanWorkspace {...props} />
    case 'CustomerHistoryWorkspace': return <CustomerHistoryWorkspace {...props} />
    case 'AdminUserControls': return <AdminUserControls {...props} profile={profile} />
    case 'OrderExport': return <OrderExport selectedOrderIds={[]} {...props} />
  }
}

export function E2ECompositionProbe() {
  const { authenticated, loading, auth } = useAuth()
  const params = new URLSearchParams(window.location.search)
  const requested = params.get('e2eComposition') ?? ''
  const names = requested.split(',').filter((name): name is ComponentName => components.includes(name as ComponentName))

  useEffect(() => {
    if (import.meta.env?.VITE_APP_ENVIRONMENT !== 'e2e') return
    console.info('[E2E-COMPOSITION-AUTH]', JSON.stringify({ authenticated, loading, hasToken: Boolean(auth.accessToken), names }))
  }, [authenticated, loading, auth.accessToken, names.join(',')])

  if (loading || !authenticated || !auth.accessToken) {
    return <div data-e2e-composition="waiting" />
  }

  console.info('[E2E-COMPOSITION-COMMIT]', JSON.stringify({ names }))
  return (
    <main data-e2e-composition={names.join(',')}>
      {names.map((name) => (
        <section data-e2e-component={name} key={name}>
          <h2>{name}</h2>
          {renderComponent(name, auth.accessToken!, auth.profile)}
        </section>
      ))}
    </main>
  )
}
