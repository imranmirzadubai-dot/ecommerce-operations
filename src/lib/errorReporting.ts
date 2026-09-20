import { logger, type LogContext } from './logger'
import { createCorrelationContext } from './correlation'

export function reportError(error: unknown, context: LogContext = {}): void {
  const errorContext: LogContext = {
    ...createCorrelationContext(typeof context.correlationId === 'string' ? context.correlationId : undefined),
    ...context,
    error: error instanceof Error
      ? { name: error.name, message: error.message, stack: error.stack }
      : { value: String(error) },
  }
  logger.error('Unhandled application error', errorContext)
}

export function installGlobalErrorReporting(): () => void {
  const onError = (event: ErrorEvent) => {
    reportError(event.error ?? event.message, { source: 'window.error' })
  }
  const onUnhandledRejection = (event: PromiseRejectionEvent) => {
    reportError(event.reason, { source: 'unhandledrejection' })
  }

  window.addEventListener('error', onError)
  window.addEventListener('unhandledrejection', onUnhandledRejection)
  return () => {
    window.removeEventListener('error', onError)
    window.removeEventListener('unhandledrejection', onUnhandledRejection)
  }
}
