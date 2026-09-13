const PUBLIC_PATHS = new Set(['/login'])
const PROTECTED_PREFIXES = ['/app']

export function isProtectedPath(pathname) {
  const path = pathname || '/'
  return PROTECTED_PREFIXES.some((prefix) => path === prefix || path.startsWith(`${prefix}/`))
}

export function isPublicPath(pathname) {
  const path = pathname || '/'
  return PUBLIC_PATHS.has(path)
}

export function safeReturnPath(pathname, search = '') {
  const path = pathname || '/'
  if (!isProtectedPath(path)) return '/app'
  return `${path}${search || ''}`
}

export function getLoginRedirect(pathname, search = '') {
  const returnPath = safeReturnPath(pathname, search)
  return `/login?returnTo=${encodeURIComponent(returnPath)}`
}

export function getPostLoginPath(search = '') {
  try {
    const value = new URLSearchParams(search).get('returnTo')
    if (!value || !value.startsWith('/app') || value.startsWith('//') || value.includes('\\')) return '/app'
    return value
  } catch {
    return '/app'
  }
}
