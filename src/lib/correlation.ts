const CORRELATION_ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/

function generateCorrelationId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  return `corr-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
}

export function createCorrelationId(candidate?: string): string {
  if (candidate && CORRELATION_ID_PATTERN.test(candidate)) return candidate
  return generateCorrelationId()
}

export type CorrelationContext = {
  correlationId: string
}

export function createCorrelationContext(candidate?: string): CorrelationContext {
  return { correlationId: createCorrelationId(candidate) }
}

export function correlationHeaders(correlationId: string): Record<string, string> {
  return { 'X-Correlation-ID': createCorrelationId(correlationId) }
}
