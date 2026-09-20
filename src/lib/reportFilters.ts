export type DatePreset = 'all' | 'today' | 'yesterday' | 'last7' | 'last30' | 'custom'
export type DateRange = { from: string; to: string }

function dateKey(value: unknown): string | null {
  if (typeof value !== 'string' || !value) return null
  const match = value.match(/^\d{4}-\d{2}-\d{2}/)
  return match ? match[0] : null
}

export function filterRowsByDate(rows: Record<string, unknown>[], dateColumn: string | undefined, range: DateRange): Record<string, unknown>[] {
  if (!dateColumn || (!range.from && !range.to)) return rows
  return rows.filter((row) => {
    const key = dateKey(row[dateColumn])
    if (!key) return false
    if (range.from && key < range.from) return false
    if (range.to && key > range.to) return false
    return true
  })
}

function formatDate(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function resolveDatePreset(preset: DatePreset, now = new Date()): DateRange {
  const today = formatDate(now)
  if (preset === 'all') return { from: '', to: '' }
  if (preset === 'today') return { from: today, to: today }
  const start = new Date(now)
  if (preset === 'yesterday') {
    start.setDate(start.getDate() - 1)
    const day = formatDate(start)
    return { from: day, to: day }
  }
  if (preset === 'last7') {
    start.setDate(start.getDate() - 6)
    return { from: formatDate(start), to: today }
  }
  if (preset === 'last30') {
    start.setDate(start.getDate() - 29)
    return { from: formatDate(start), to: today }
  }
  return { from: today, to: today }
}
