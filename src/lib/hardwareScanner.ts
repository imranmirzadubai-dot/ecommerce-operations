export type ScannerKey = { key: string; at: number }

export type ScannerInputConfig = {
  interKeyTimeoutMs?: number
  minLength?: number
  terminator?: string
}

export type ScannerInputResult = {
  value: string
  accepted: boolean
}

const DEFAULT_TIMEOUT_MS = 80
const DEFAULT_MIN_LENGTH = 4
const DEFAULT_TERMINATOR = 'Enter'

/**
 * Parse a USB/Bluetooth barcode scanner operating in keyboard-wedge mode.
 * The scanner emits characters as keyboard events and terminates with Enter.
 * A long gap resets the buffer so ordinary human typing is not accepted as a scan.
 */
export function parseScannerKeySequence(keys: ScannerKey[], config: ScannerInputConfig = {}): ScannerInputResult {
  const timeout = config.interKeyTimeoutMs ?? DEFAULT_TIMEOUT_MS
  const minLength = config.minLength ?? DEFAULT_MIN_LENGTH
  const terminator = config.terminator ?? DEFAULT_TERMINATOR
  if (keys.length === 0) return { value: '', accepted: false }

  let buffer = ''
  let previousAt: number | null = null
  for (const event of keys) {
    if (previousAt !== null && event.at - previousAt > timeout) {
      buffer = ''
    }
    previousAt = event.at
    if (event.key === terminator) {
      const value = buffer.trim()
      return { value, accepted: value.length >= minLength }
    }
    if (event.key.length === 1) buffer += event.key
  }
  return { value: buffer, accepted: false }
}
