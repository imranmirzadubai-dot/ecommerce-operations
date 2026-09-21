export function getRecoveryToken(): string | null {
  const params = new URLSearchParams(window.location.hash.replace(/^#/, ''))
  if (params.get('type') !== 'recovery') return null
  return params.get('access_token')
}

export function isPasswordRecoveryCallback(): boolean {
  return getRecoveryToken() !== null
}
