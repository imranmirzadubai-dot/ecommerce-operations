import { useAuth } from './lib/AuthContext'
import { OrdersWorkspace } from './components/OrdersWorkspace'

const TOKEN = 'T227-010-DIAGNOSTIC-TOKEN'

export function T227010AuthOrdersControl() {
  const { loading, authenticated, accessToken } = useAuth()
  return (
    <div data-t227010-token="T227-010-DIAGNOSTIC-TOKEN" data-auth-loading={String(loading)} data-authenticated={String(authenticated)}>
      <div data-t227010-state>{loading ? 'AUTH_LOADING' : authenticated ? 'AUTHENTICATED' : 'AUTH_SIGNED_OUT'}</div>
      <OrdersWorkspace accessToken={accessToken ?? TOKEN} />
    </div>
  )
}
