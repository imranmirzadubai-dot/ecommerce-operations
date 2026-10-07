import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { canAdministerUsers, getAuthConfig, type Profile } from '../lib/auth'
import '../styles/admin-responsive.css'

export function AdminUserControls({ accessToken, profile }: { accessToken: string; profile: Profile | null }) {
  const [profiles, setProfiles] = useState<Profile[]>([])
  const [loading, setLoading] = useState(true)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  type ApplicationRole = 'sales' | 'operations' | 'admin'
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviteName, setInviteName] = useState('')
  const [inviteRole, setInviteRole] = useState<ApplicationRole>('operations')
  const [inviting, setInviting] = useState(false)
  const [userId, setUserId] = useState('')
  const [name, setName] = useState('')
  const [role, setRole] = useState<ApplicationRole>('sales')
  const [showAdvancedLink, setShowAdvancedLink] = useState(false)
  const config = getAuthConfig()

  async function loadProfiles() {
    if (!config || !canAdministerUsers(profile)) return
    setLoading(true); setError('')
    try {
      const response = await fetch(`${config.url}/rest/v1/profiles?select=id,name,email,role,active&order=name.asc`, { headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' } })
      if (!response.ok) throw new Error('Unable to load administrator user profiles')
      setProfiles((await response.json()) as Profile[])
    } catch (loadError) { setError(loadError instanceof Error ? loadError.message : 'Unable to load user profiles') }
    finally { setLoading(false) }
  }

  useEffect(() => {
    const timer = window.setTimeout(() => { void loadProfiles() }, 0)
    return () => window.clearTimeout(timer)
    // loadProfiles is intentionally scoped to the current authenticated profile.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [accessToken, profile])

  async function rpc<T>(name: string, body: Record<string, unknown>): Promise<T> {
    if (!config) throw new Error('Supabase authentication is not configured for this environment')
    const response = await fetch(`${config.url}/rest/v1/rpc/${name}`, { method: 'POST', headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify(body) })
    const payload = await response.json().catch(() => null) as { message?: string; details?: string } | T | null
    if (!response.ok) { const detail = payload as { message?: string; details?: string } | null; throw new Error(detail?.message ?? detail?.details ?? `Request failed (${response.status})`) }
    return payload as T
  }

  async function inviteUser(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setMessage(''); setError(''); setInviting(true)
    try {
      const response = await fetch('/api/admin/users/invite', {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', Accept: 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ email: inviteEmail.trim().toLowerCase(), name: inviteName.trim(), role: inviteRole }),
      })
      const payload = await response.json().catch(() => null) as { error?: string; invitation_created?: boolean; cleanup_failed?: boolean } | null
      if (!response.ok) {
        const messages: Record<string, string> = {
          invalid_email: 'Enter a valid email address.',
          invalid_name: 'Enter a valid user name.',
          invalid_role: 'Select a valid application role.',
          invite_failed: 'The invitation could not be sent. Check whether this email already has an Auth account.',
          profile_provisioning_failed: payload?.invitation_created === false ? 'User creation was rolled back because the application profile could not be created. No active invitation remains; verify the system before retrying.' : 'The Auth invitation was created, but the application profile could not be created and cleanup did not complete. Do not resend yet; this needs administrator review.',
          authentication_required: 'Your admin session has expired. Sign in again.',
          forbidden: 'Only an active Admin can create users.',
          server_not_configured: 'User invitation is not configured in this environment.',
        }
        throw new Error(messages[payload?.error ?? ''] ?? 'Unable to create user invitation.')
      }
      setInviteEmail(''); setInviteName(''); setInviteRole('operations')
      setMessage('Invitation sent. The Auth user and application profile were created automatically.')
      await loadProfiles()
    } catch (inviteError) {
      setError(inviteError instanceof Error ? inviteError.message : 'Unable to create user invitation')
    } finally {
      setInviting(false)
    }
  }

  async function linkProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setMessage(''); setError('')
    try {
      await rpc<Profile>('create_profile', { p_user_id: userId.trim(), p_name: name.trim(), p_role: role })
      setUserId(''); setName(''); setRole('sales'); setMessage('Profile linked successfully.'); await loadProfiles()
    } catch (linkError) { setError(linkError instanceof Error ? linkError.message : 'Profile linking failed') }
  }

  async function setActive(target: Profile) {
    setMessage(''); setError('')
    try {
      await rpc<Profile>('set_profile_active', { p_user_id: target.id, p_active: !target.active })
      setMessage(`${target.name} is now ${target.active ? 'inactive' : 'active'}.`); await loadProfiles()
    } catch (statusError) { setError(statusError instanceof Error ? statusError.message : 'Unable to change profile status') }
  }

  if (!canAdministerUsers(profile)) return null

  return <section className="card admin-users-card" aria-labelledby="admin-users-title">
    <div className="section-heading"><div><span className="eyebrow">Administration</span><h2 id="admin-users-title">User controls</h2><p>Admin-only profile management. Auth identities are not deleted from this workspace.</p></div><span className="check">Admin only</span></div>
    <div className="section-heading"><div><span className="eyebrow">Create user</span><h3>Invite a new user</h3><p>Enter the email, name and application role. Supabase creates the Auth identity and application profile automatically.</p></div></div>
    <form className="admin-user-form" onSubmit={inviteUser}>
      <label>Email<input type="email" value={inviteEmail} onChange={(event) => setInviteEmail(event.target.value)} placeholder="user@example.com" autoComplete="email" required /></label>
      <label>Profile name<input value={inviteName} onChange={(event) => setInviteName(event.target.value)} placeholder="Full name" autoComplete="name" required /></label>
      <label>Application role<select value={inviteRole} onChange={(event) => setInviteRole(event.target.value as ApplicationRole)}><option value="sales">Sales</option><option value="operations">Operations</option><option value="admin">Admin</option></select></label>
      <button className="login-button" type="submit" disabled={inviting}>{inviting ? 'Sending invitation…' : 'Create & invite user'}</button>
    </form>
    {message && <p className="form-success" role="status">{message}</p>}{error && <p className="form-error" role="alert">{error}</p>}
    <details open={showAdvancedLink} onToggle={(event) => setShowAdvancedLink(event.currentTarget.open)}>
      <summary>Advanced: link an existing Auth user</summary>
      <p>If an Auth identity already exists without an application profile, enter its Auth User ID here. This is not required for normal user creation.</p>
      <form className="admin-user-form" onSubmit={linkProfile}>
        <label>Auth user ID<input value={userId} onChange={(event) => setUserId(event.target.value)} placeholder="UUID of existing Auth user" required /></label>
        <label>Profile name<input value={name} onChange={(event) => setName(event.target.value)} required /></label>
        <label>Application role<select value={role} onChange={(event) => setRole(event.target.value as ApplicationRole)}><option value="sales">Sales</option><option value="operations">Operations</option><option value="admin">Admin</option></select></label>
        <button className="secondary-button" type="submit">Link existing profile</button>
      </form>
    </details>
    <div className="orders-table-wrap admin-users-table-wrap"><table className="orders-table"><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Status</th><th>Control</th></tr></thead><tbody>{loading ? <tr><td colSpan={5}>Loading profiles…</td></tr> : profiles.map((item) => <tr key={item.id}><td><strong>{item.name}</strong><small>{item.id}</small></td><td>{item.email}</td><td>{item.role}</td><td><span className="state-pill">{item.active ? 'Active' : 'Inactive'}</span></td><td><button className="secondary-button" type="button" onClick={() => void setActive(item)}>{item.active ? 'Deactivate' : 'Activate'}</button></td></tr>)}{!loading && profiles.length === 0 && <tr><td colSpan={5}>No application profiles found.</td></tr>}</tbody></table></div>
  </section>
}
