export type AppRole = 'sales' | 'operations' | 'admin'

export type Profile = {
  id: string
  name: string
  email: string
  role: AppRole
  active: boolean
}

export type AuthState = {
  authenticated: boolean
  userId: string | null
  profile: Profile | null
}

export function hasOperationalAccess(profile: Profile | null): boolean {
  return profile?.active === true && ['sales', 'operations', 'admin'].includes(profile.role)
}

export function canAdministerUsers(profile: Profile | null): boolean {
  return profile?.active === true && profile.role === 'admin'
}
