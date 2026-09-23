import { OrdersWorkspace } from './components/OrdersWorkspace'

const TOKEN = 'T227-007-DIAGNOSTIC-TOKEN'

export function T227007OrdersEffectControl() {
  const skipInitialLoad = new URLSearchParams(window.location.search).get('effect') === 'off'
  return (
    <div data-t227007-effect={skipInitialLoad ? 'off' : 'on'} data-t227007-token={TOKEN}>
      <OrdersWorkspace accessToken={TOKEN} skipInitialLoad={skipInitialLoad} />
    </div>
  )
}
