import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { AuthProvider } from './lib/AuthContext'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'
import { T227007OrdersEffectControl } from './T227007OrdersEffectControl'

// This entry-point intentionally owns the bootstrap component; Fast Refresh is not used here.
// eslint-disable-next-line react-refresh/only-export-components
function ErrorReportingBootstrap() {
  useEffect(() => installGlobalErrorReporting(), [])
  return null
}

const diagnosticParams = new URLSearchParams(window.location.search)
const strictModeDiagnostic = diagnosticParams.get('t227006') === '1'
const strictModeEnabled = diagnosticParams.get('strict') !== 'off'
const ordersEffectDiagnostic = diagnosticParams.get('t227007') === '1'

const bootstrap = (
  <ErrorBoundary>
    <ErrorReportingBootstrap />
    <AuthProvider>
      {ordersEffectDiagnostic ? <T227007OrdersEffectControl /> : <RouteGuard />}
    </AuthProvider>
  </ErrorBoundary>
)

createRoot(document.getElementById('root')!).render(
  strictModeDiagnostic && !strictModeEnabled ? bootstrap : <StrictMode>{bootstrap}</StrictMode>,
)
