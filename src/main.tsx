import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { AuthProvider } from './lib/AuthContext'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'
import { T227010AuthOrdersControl } from './T227010AuthOrdersControl'

// This entry-point intentionally owns the bootstrap component; Fast Refresh is not used here.
// eslint-disable-next-line react-refresh/only-export-components
function ErrorReportingBootstrap() {
  useEffect(() => installGlobalErrorReporting(), [])
  return null
}

const diagnostic = new URLSearchParams(window.location.search).get('t227010') === '1'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <ErrorReportingBootstrap />
      <AuthProvider>
        {diagnostic ? <T227010AuthOrdersControl /> : <RouteGuard />}
      </AuthProvider>
    </ErrorBoundary>
  </StrictMode>,
)
