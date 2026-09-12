export const APP_ROLES = ['sales', 'operations', 'admin'] as const

export type AppRole = (typeof APP_ROLES)[number]

export const APP_ROLE_LABELS: Record<AppRole, string> = {
  sales: 'Sales',
  operations: 'Operations',
  admin: 'Admin',
}

export function isAppRole(value: unknown): value is AppRole {
  return typeof value === 'string' && (APP_ROLES as readonly string[]).includes(value)
}

export function roleLabel(role: AppRole): string {
  return APP_ROLE_LABELS[role]
}
