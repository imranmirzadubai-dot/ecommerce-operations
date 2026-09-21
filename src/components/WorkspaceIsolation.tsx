import type { ReactNode } from 'react'

type Props = {
  modes: string[]
  children: ReactNode
}

function requestedWorkspace(): string {
  try {
    return new URLSearchParams(window.location.search).get('only')?.trim().toLowerCase() || 'all'
  } catch {
    return 'all'
  }
}

export function WorkspaceIsolation({ modes, children }: Props) {
  const requested = requestedWorkspace()
  if (requested === 'all' || modes.includes(requested)) return <>{children}</>
  return null
}
