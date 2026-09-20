export type AlertSeverity = 'info' | 'warning' | 'critical'

export type AlertCondition = {
  name: string
  threshold: number
  severity: AlertSeverity
  direction: 'above' | 'below'
}

export type AlertEvent = {
  name: string
  severity: AlertSeverity
  value: number
  threshold: number
  triggered: boolean
  timestamp: string
  context: Record<string, string | number | boolean>
}

export function evaluateAlert(
  condition: AlertCondition,
  value: number,
  context: Record<string, string | number | boolean> = {},
  now: Date = new Date(),
): AlertEvent {
  if (!condition.name.trim()) throw new Error('Alert name is required')
  if (!Number.isFinite(condition.threshold)) throw new Error('Alert threshold must be finite')
  if (!Number.isFinite(value)) throw new Error('Alert value must be finite')

  const triggered = condition.direction === 'above'
    ? value > condition.threshold
    : value < condition.threshold

  return {
    name: condition.name,
    severity: condition.severity,
    value,
    threshold: condition.threshold,
    triggered,
    timestamp: now.toISOString(),
    context: { ...context },
  }
}

export function shouldNotify(alert: AlertEvent): boolean {
  return alert.triggered
}
