export type MetricTags = Record<string, string | number | boolean>

export type MetricSample = {
  name: string
  value: number
  unit: 'ms' | 'count'
  timestamp: string
  tags: MetricTags
}

export function createMetricSample(name: string, value: number, unit: MetricSample['unit'], tags: MetricTags = {}, now: Date = new Date()): MetricSample {
  if (!name.trim()) throw new Error('Metric name is required')
  if (!Number.isFinite(value) || value < 0) throw new Error('Metric value must be a finite non-negative number')
  return { name, value, unit, timestamp: now.toISOString(), tags: { ...tags } }
}

export function measureDuration<T>(name: string, operation: () => T, tags: MetricTags = {}, now: () => number = () => performance.now()): { result: T; metric: MetricSample } {
  const started = now()
  try {
    const result = operation()
    return { result, metric: createMetricSample(name, Math.max(0, now() - started), 'ms', tags) }
  } catch (error) {
    createMetricSample(name, Math.max(0, now() - started), 'ms', { ...tags, outcome: 'error' })
    throw error
  }
}

export async function measureAsyncDuration<T>(name: string, operation: () => Promise<T>, tags: MetricTags = {}, now: () => number = () => performance.now()): Promise<{ result: T; metric: MetricSample }> {
  const started = now()
  try {
    const result = await operation()
    return { result, metric: createMetricSample(name, Math.max(0, now() - started), 'ms', tags) }
  } catch (error) {
    createMetricSample(name, Math.max(0, now() - started), 'ms', { ...tags, outcome: 'error' })
    throw error
  }
}
