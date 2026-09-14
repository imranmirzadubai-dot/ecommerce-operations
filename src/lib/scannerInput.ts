export type ScannerInputOptions = {
  maxLength?: number
}

const DEFAULT_MAX_LENGTH = 128

/**
 * Normalizes a barcode-scanner keyboard-wedge payload.
 *
 * Scanner hardware configured as HID/keyboard-wedge input delivers the decoded
 * barcode as ordinary keyboard text and commonly appends Enter/CR/LF. The
 * parser deliberately accepts only printable ASCII barcode content and treats
 * trailing CR/LF as transport terminators rather than barcode data.
 */
export function normalizeScannerInput(raw: string, options: ScannerInputOptions = {}): string {
  const maxLength = options.maxLength ?? DEFAULT_MAX_LENGTH
  const value = raw.replace(/[\r\n]+$/g, '')

  if (!value) throw new Error('Scanner input is empty')
  if (value.length > maxLength) throw new Error('Scanner input exceeds the maximum length')
  if (!/^[\x20-\x7E]+$/.test(value)) throw new Error('Scanner input contains unsupported control characters')

  return value
}

/**
 * Completes a keyboard-wedge scan when the scanner's configured terminator
 * (normally Enter) is received. Non-terminator keystrokes are accumulated.
 */
export function consumeScannerKey(buffer: string, key: string, options: ScannerInputOptions = {}): {
  buffer: string
  value: string | null
} {
  if (key === 'Enter' || key === '\r' || key === '\n') {
    return { buffer: '', value: normalizeScannerInput(buffer, options) }
  }

  if (key.length !== 1) return { buffer, value: null }
  const next = buffer + key
  normalizeScannerInput(next, { ...options, maxLength: options.maxLength ?? DEFAULT_MAX_LENGTH })
  return { buffer: next, value: null }
}
