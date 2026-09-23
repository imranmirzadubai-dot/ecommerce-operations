import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { T227011OrdersGridControl } from './T227011OrdersGridControl'
import { T227012OrdersParentControl } from './T227012OrdersParentControl'
import { T227013OrdersDivParentControl } from './T227013OrdersDivParentControl'
import { AuthProvider } from './lib/AuthContext'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'

// This entry-point intentionally owns the bootstrap component; Fast Refresh is not used here.
// eslint-disable-next-line react-refresh/only-export-components
const ordersGridDiagnostic = typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('t227011') === '1'
const ordersDivParentDiagnostic = typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('t227013') === '1'
const ordersParentDiagnostic = typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('t227012') === '1'

// eslint-disable-next-line react-refresh/only-export-components
function ErrorReportingBootstrap() {
  useEffect(() => installGlobalErrorReporting(), [])
  return null
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <ErrorReportingBootstrap />
      <AuthProvider>
        {ordersDivParentDiagnostic ? <T227013OrdersDivParentControl /> : ordersParentDiagnostic ? <T227012OrdersParentControl /> : ordersGridDiagnostic ? <T227011OrdersGridControl /> : <RouteGuard />}
      </AuthProvider>
    </ErrorBoundary>
  </StrictMode>,
)
