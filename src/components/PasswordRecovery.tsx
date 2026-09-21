import { useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { getAuthConfig } from '../lib/auth'
import { getRecoveryToken } from '../lib/passwordRecovery'

const RECOVERY_TIMEOUT_MS = 8_000

async function updatePassword(accessToken: string, password: string): Promise<void> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase authentication is not configured for this environment')

  const controller = new AbortController()
  const timeout = window.setTimeout(() => controller.abort(), RECOVERY_TIMEOUT_MS)
  try {
    const response = await fetch(`${config.url}/auth/v1/user`, {
      method: 'PUT',
      signal: controller.signal,
      headers: {
        apikey: config.publishableKey,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ password }),
    })

    if (!response.ok) {
      const payload = (await response.json().catch(() => null)) as { msg?: string; error_description?: string; message?: string } | null
      throw new Error(payload?.msg ?? payload?.error_description ?? payload?.message ?? 'Unable to update password')
    }
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('Password update request timed out', { cause: error })
    }
    throw error
  } finally {
    window.clearTimeout(timeout)
  }
}

export function PasswordRecovery() {
  const token = useMemo(getRecoveryToken, [])
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [success, setSuccess] = useState(false)

  if (!token) return null

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    if (password.length < 8) {
      setError('Password must be at least 8 characters.')
      return
    }
    if (password !== confirmation) {
      setError('The passwords do not match.')
      return
    }

    setSaving(true)
    try {
      await updatePassword(token, password)
      window.history.replaceState({}, '', '/login')
      setSuccess(true)
      setPassword('')
      setConfirmation('')
    } catch (updateError) {
      setError(updateError instanceof Error ? updateError.message : 'Unable to update password')
    } finally {
      setSaving(false)
    }
  }

  function returnToLogin() {
    window.location.replace('/login')
  }

  return (
    <div className="operations-app">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark">EO</span>
          <div><strong>E-Commerce Operations</strong><span>Operations workspace</span></div>
        </div>
        <div className="environment"><span className="status-dot" /><span>{(import.meta.env.VITE_APP_ENVIRONMENT?.trim() || import.meta.env.MODE).toUpperCase()}</span></div>
      </header>
      <main className="content">
        <section className="access-panel" aria-labelledby="password-recovery-title">
          <div className="access-icon">✓</div>
          <div>
            <span className="eyebrow">Authentication boundary</span>
            <h2 id="password-recovery-title">{success ? 'Password updated' : 'Set a new password'}</h2>
            {success ? (
              <>
                <p>Your password has been updated successfully. Sign in with the new password.</p>
                <button className="login-button" type="button" onClick={returnToLogin}>Return to sign in</button>
              </>
            ) : (
              <form className="login-form" onSubmit={handleSubmit}>
                <label>New password<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="new-password" minLength={8} required /></label>
                <label>Confirm new password<input type="password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} autoComplete="new-password" minLength={8} required /></label>
                <button className="login-button" type="submit" disabled={saving}>{saving ? 'Updating password…' : 'Update password'}</button>
                {error && <p className="form-error" role="alert">{error}</p>}
              </form>
            )}
          </div>
        </section>
      </main>
    </div>
  )
}
