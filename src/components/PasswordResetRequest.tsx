import { useState } from 'react'
import type { FormEvent } from 'react'
import { requestPasswordReset } from '../lib/auth'

type PasswordResetRequestProps = { defaultEmail?: string }

export function PasswordResetRequest({ defaultEmail = '' }: PasswordResetRequestProps) {
  const [open, setOpen] = useState(false)
  const [email, setEmail] = useState(defaultEmail)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [sending, setSending] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setMessage('')
    setError('')
    setSending(true)
    try {
      await requestPasswordReset(email.trim())
      setMessage('If an account exists for this email, a password reset link has been sent.')
    } catch (resetError) {
      setError(resetError instanceof Error ? resetError.message : 'Unable to send password reset email')
    } finally {
      setSending(false)
    }
  }

  if (!open) {
    return <button className="secondary-button" type="button" onClick={() => setOpen(true)}>Forgot password?</button>
  }

  return (
    <div className="password-reset-request">
      <button className="secondary-button" type="button" onClick={() => setOpen(false)}>Back to sign in</button>
      <form className="login-form" onSubmit={handleSubmit}>
        <label>Account email<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" required /></label>
        <button className="login-button" type="submit" disabled={sending}>{sending ? 'Sending reset email…' : 'Send reset email'}</button>
        {message && <p className="form-success" role="status">{message}</p>}
        {error && <p className="form-error" role="alert">{error}</p>}
      </form>
    </div>
  )
}
