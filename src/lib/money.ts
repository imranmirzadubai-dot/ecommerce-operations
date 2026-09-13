const MAX_AED_AMOUNT = '9999999999.99'

/**
 * Validate and canonicalize the manually entered AED order total.
 * The value stays decimal text at the application boundary so the browser
 * does not perform floating-point arithmetic on the commercial amount.
 */
export function normalizeAedAmount(value: string): string {
  const input = value.trim()
  if (!/^\d+(?:\.\d{1,2})?$/.test(input)) {
    throw new Error('Enter a valid Total Order Amount with up to 2 decimal places')
  }

  const [wholePart, fractionPart = ''] = input.split('.')
  const whole = wholePart.replace(/^0+(?=\d)/, '')
  const fraction = fractionPart.padEnd(2, '0')
  const canonical = `${whole}.${fraction}`

  if (canonical.length > MAX_AED_AMOUNT.length || (canonical.length === MAX_AED_AMOUNT.length && canonical > MAX_AED_AMOUNT)) {
    throw new Error('Total Order Amount exceeds the AED maximum supported by the MVP')
  }

  return canonical
}
