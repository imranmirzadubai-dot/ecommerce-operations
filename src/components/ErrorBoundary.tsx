import { Component, type ErrorInfo, type ReactNode } from 'react'
import { reportError } from '../lib/errorReporting'

type Props = { children: ReactNode }
type State = { hasError: boolean }

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false }

  static getDerivedStateFromError(): State {
    return { hasError: true }
  }

  componentDidCatch(error: unknown, info: ErrorInfo): void {
    reportError(error, { source: 'react.error-boundary', componentStack: info.componentStack })
  }

  render() {
    if (!this.state.hasError) return this.props.children
    return (
      <main role="alert" style={{ padding: '2rem', fontFamily: 'sans-serif' }}>
        <h1>Something went wrong</h1>
        <p>The error was recorded locally. Reload the page to continue.</p>
        <button type="button" onClick={() => window.location.reload()}>Reload</button>
      </main>
    )
  }
}
