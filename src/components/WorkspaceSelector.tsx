import { useEffect } from 'react'
import type { AppRole } from '../lib/roles'
import { getPostLoginPath } from '../lib/routes'

type Workspace = 'operations' | 'admin'

type WorkspaceSelectorProps = {
  name: string
  role: AppRole
  onSelect: (workspace: Workspace) => void
}

export function WorkspaceSelector({ name, role, onSelect }: WorkspaceSelectorProps) {
  const canAdmin = role === 'admin'
  const diagnosticEnvironment = import.meta.env.VITE_E2E_DIAGNOSTIC

  useEffect(() => {
    if (diagnosticEnvironment === 't227-003') {
      const pageHeading = document.querySelector('main.content .page-heading h1')
      if (pageHeading) pageHeading.setAttribute('role', 'presentation')
      return
    }

    if (!['t227-004', 't227-005', 't227-006'].includes(diagnosticEnvironment)) return
    const postLoginPath = getPostLoginPath(window.location.search)
    const navigationMode = diagnosticEnvironment === 't227-005' || diagnosticEnvironment === 't227-006'
      ? new URLSearchParams(window.location.search).get('navigation')
      : null

    if (navigationMode === 'soft') {
      window.history.replaceState({}, '', postLoginPath)
      window.dispatchEvent(new PopStateEvent('popstate'))
    } else {
      window.location.replace(postLoginPath)
    }
  }, [diagnosticEnvironment])

  function selectWorkspace(workspace: Workspace) {
    onSelect(workspace)
    if (diagnosticEnvironment !== 't227-003') return
    const postLoginPath = getPostLoginPath(window.location.search)
    const diagnosticTarget = new URL(postLoginPath, window.location.origin).searchParams.get('workspace')
    if (!diagnosticTarget) return
    window.history.replaceState({}, '', postLoginPath)
    window.dispatchEvent(new PopStateEvent('popstate'))
  }

  return (
    <section className="access-panel workspace-selector" aria-labelledby="workspace-selector-title">
      <div className="access-icon">✓</div>
      <div>
        <span className="eyebrow">Authenticated</span>
        <h2 id="workspace-selector-title">Select workspace</h2>
        <p>{name}, choose where you want to continue.</p>
        <div className="workspace-choice-grid" role="group" aria-label="Available workspaces">
          <button className="workspace-choice" type="button" onClick={() => selectWorkspace('operations')}>
            <strong>Operations</strong>
            <span>Orders, parcels, dispatch, delivery and finance.</span>
          </button>
          {canAdmin && (
            <button className="workspace-choice" type="button" onClick={() => selectWorkspace('admin')}>
              <strong>Admin</strong>
              <span>User administration and administrative controls.</span>
            </button>
          )}
        </div>
      </div>
      <div className="access-state">{canAdmin ? '2 workspaces' : '1 workspace'}</div>
    </section>
  )
}
