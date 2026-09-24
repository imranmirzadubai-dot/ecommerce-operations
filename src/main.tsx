import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { AuthProvider } from './lib/AuthContext'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'

// This entry-point intentionally owns the bootstrap component; Fast Refresh is not used here.
// eslint-disable-next-line react-refresh/only-export-components
function ErrorReportingBootstrap() {
  useEffect(() => installGlobalErrorReporting(), [])
  return null
}

const application = (
  <ErrorBoundary>
    <ErrorReportingBootstrap />
    <AuthProvider>
      <RouteGuard />
    </AuthProvider>
  </ErrorBoundary>
)

const diagnosticStrictMode =
  import.meta.env.VITE_E2E_DIAGNOSTIC !== 't227-006' ||
  new URLSearchParams(window.location.search).get('strict') === 'on'

createRoot(document.getElementById('root')!).render(
  diagnosticStrictMode ? <StrictMode>{application}</StrictMode> : application,
)
