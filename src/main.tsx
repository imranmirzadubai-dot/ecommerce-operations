import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { RouteGuard } from './RouteGuard.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <RouteGuard />
  </StrictMode>,
)
