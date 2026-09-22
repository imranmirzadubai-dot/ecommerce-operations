import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { AuthProvider } from './lib/AuthContext'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'

const buildStamp = {
  sha: import.meta.env.VITE_GIT_SHA ?? 'unset',
  builtAt: import.meta.env.VITE_BUILD_TIME ?? 'unset',
}
;(window as typeof window & { __buildStamp?: typeof buildStamp }).__buildStamp = buildStamp
console.log('[BUILD_STAMP]', buildStamp)

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
      <AuthProvider>
        <RouteGuard />
      </AuthProvider>
    </ErrorBoundary>
  </StrictMode>,
)
