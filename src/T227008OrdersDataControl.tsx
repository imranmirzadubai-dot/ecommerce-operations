import { OrdersWorkspace } from './components/OrdersWorkspace'

const TOKEN = 'T227-008-DIAGNOSTIC-TOKEN'

export function T227008OrdersDataControl() {
  return (
    <div data-t227008-token={TOKEN}>
      <OrdersWorkspace accessToken={TOKEN} />
    </div>
  )
}
