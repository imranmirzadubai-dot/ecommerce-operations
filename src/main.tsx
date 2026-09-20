import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'

// This entry-point intentionally owns the bootstrap component; Fast Refresh is not used here.
// eslint-disable-next-line react-refresh/only-export-components
function ErrorReportingBootstrap() {
  useEffect(() => installGlobalErrorReporting(), [])
  return null
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <ErrorReportingBootstrap />
      <RouteGuard />
    </ErrorBoundary>
  </StrictMode>,
)
