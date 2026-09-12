const PUBLIC_PATHS = new Set(['/login'])

export function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.has(pathname || '/')
}

export function isProtectedPath(pathname: string): boolean {
  return !isPublicPath(pathname)
}

export function safeReturnPath(pathname: string, search = ''): string {
  const path = pathname || '/'
  if (isPublicPath(path) || path.startsWith('//') || path.includes('\\') || /^[a-z][a-z\d+.-]*:/i.test(path)) return '/'
  return `${path}${search || ''}`
}

export function getLoginRedirect(pathname: string, search = ''): string {
  return `/login?returnTo=${encodeURIComponent(safeReturnPath(pathname, search))}`
}

export function getPostLoginPath(search = ''): string {
  try {
    const value = new URLSearchParams(search).get('returnTo')
    if (!value || isPublicPath(value) || value.startsWith('//') || value.includes('\\') || /^[a-z][a-z\d+.-]*:/i.test(value) || !value.startsWith('/')) return '/'
    return value
  } catch {
    return '/'
  }
}
