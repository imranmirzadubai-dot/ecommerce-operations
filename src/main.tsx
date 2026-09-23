import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'
import { AuthProvider } from './lib/AuthContext'
import { ErrorBoundary } from './components/ErrorBoundary.tsx'
import { E2ECompositionProbe } from './components/E2ECompositionProbe.tsx'
import { installGlobalErrorReporting } from './lib/errorReporting'

const buildStamp = {
  sha: import.meta.env.VITE_GIT_SHA ?? 'unset',
  builtAt: import.meta.env.VITE_BUILD_TIME ?? 'unset',
}
;(window as typeof window & { __buildStamp?: typeof buildStamp }).__buildStamp = buildStamp
console.log('[BUILD_STAMP]', buildStamp)

function ErrorReportingBootstrap() {
  useEffect(() => installGlobalErrorReporting(), [])
  return null
}

function BootstrapRouter() {
  const isCompositionProbe = import.meta.env?.VITE_APP_ENVIRONMENT === 'e2e'
    && window.location.pathname === '/app'
    && new URLSearchParams(window.location.search).has('e2eComposition')
  return isCompositionProbe ? <E2ECompositionProbe /> : <RouteGuard />
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <ErrorReportingBootstrap />
      <AuthProvider>
        <BootstrapRouter />
      </AuthProvider>
    </ErrorBoundary>
  </StrictMode>,
)
