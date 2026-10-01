import type { ReactNode } from 'react'

type Props = {
  activeWorkspace: string
  authenticated: boolean
  canAdmin: boolean
  menuOpen: boolean
  onNavigate: (workspace: string) => void
  onToggleMenu: () => void
  onCloseMenu: () => void
  signOut: () => void
}

const primaryItems = [
  { label: 'Home', workspace: 'Dashboard', icon: '⌂' },
  { label: 'Orders', workspace: 'Orders', icon: '▣' },
  { label: 'Scan', workspace: 'Dispatch', icon: '⌁' },
  { label: 'Reports', workspace: 'Reports', icon: '▤' },
]

const menuItems = ['Dashboard', 'Orders', 'Parcels', 'Dispatch', 'Delivery / NDR', 'COD & Finance', 'Invoices', 'Reports', 'Customers']

export function MobileNavigation({ activeWorkspace, authenticated, canAdmin, menuOpen, onNavigate, onToggleMenu, onCloseMenu, signOut }: Props) {
  function navigate(workspace: string) {
    onNavigate(workspace)
    onCloseMenu()
  }

  return <>
    <nav className="mobile-bottom-nav" aria-label="Mobile primary navigation">
      {primaryItems.map((item) => (
        <button
          className={activeWorkspace === item.workspace ? 'mobile-bottom-item active' : 'mobile-bottom-item'}
          disabled={!authenticated}
          key={item.workspace}
          onClick={() => navigate(item.workspace)}
          type="button"
        >
          <span className="mobile-bottom-icon" aria-hidden="true">{item.icon}</span>
          <span>{item.label}</span>
        </button>
      ))}
      <button className={menuOpen ? 'mobile-bottom-item active' : 'mobile-bottom-item'} disabled={!authenticated} onClick={onToggleMenu} type="button">
        <span className="mobile-bottom-icon" aria-hidden="true">•••</span>
        <span>More</span>
      </button>
    </nav>

    {menuOpen && authenticated && (
      <div className="mobile-menu-backdrop" role="presentation" onClick={onCloseMenu}>
        <section className="mobile-menu-sheet" aria-label="Mobile navigation menu" onClick={(event) => event.stopPropagation()}>
          <div className="mobile-menu-header">
            <div>
              <strong>E-Commerce Operations</strong>
              <span>Operations workspace</span>
            </div>
            <button className="mobile-menu-close" type="button" onClick={onCloseMenu} aria-label="Close menu">×</button>
          </div>
          <div className="mobile-menu-list">
            {menuItems.map((item) => (
              <button className={activeWorkspace === item ? 'mobile-menu-item active' : 'mobile-menu-item'} key={item} type="button" onClick={() => navigate(item)}>
                <span>{item}</span>
                <span aria-hidden="true">›</span>
              </button>
            ))}
            {canAdmin && (
              <button className={activeWorkspace === 'Admin Users' ? 'mobile-menu-item active' : 'mobile-menu-item'} type="button" onClick={() => navigate('Admin Users')}>
                <span>Admin Users</span><span aria-hidden="true">›</span>
              </button>
            )}
            <button className="mobile-menu-item danger" type="button" onClick={signOut}>
              <span>Sign out</span><span aria-hidden="true">↗</span>
            </button>
          </div>
        </section>
      </div>
    )}
  </>
}
