import type { AppRole } from '../lib/roles'

type Workspace = 'operations' | 'admin'

type WorkspaceSelectorProps = {
  name: string
  role: AppRole
  onSelect: (workspace: Workspace) => void
}

export function WorkspaceSelector({ name, role, onSelect }: WorkspaceSelectorProps) {
  const canAdmin = role === 'admin'

  return (
    <section className="access-panel workspace-selector" aria-labelledby="workspace-selector-title">
      <div className="access-icon">✓</div>
      <div>
        <span className="eyebrow">Authenticated</span>
        <h2 id="workspace-selector-title">Select workspace</h2>
        <p>{name}, choose where you want to continue.</p>
        <div className="workspace-choice-grid" role="group" aria-label="Available workspaces">
          <button className="workspace-choice" type="button" onClick={() => onSelect('operations')}>
            <strong>Operations</strong>
            <span>Orders, parcels, dispatch, delivery and finance.</span>
          </button>
          {canAdmin && (
            <button className="workspace-choice" type="button" onClick={() => onSelect('admin')}>
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
