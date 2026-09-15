import { dispatchParcel, type DispatchParcelInput, type DispatchParcelResult } from './parcelCommands'

export type BulkDispatchItem = Omit<DispatchParcelInput, 'p_idempotency_key'> & {
  p_idempotency_key?: string
}

export type BulkDispatchResult = {
  item: BulkDispatchItem
  status: 'success' | 'failure'
  result?: DispatchParcelResult[]
  error?: string
}

/**
 * Executes bulk dispatch as orchestration around the authoritative individual
 * dispatch command. Each parcel remains an independent transaction. Results
 * are reported per parcel so successful mutations can be retained while failed
 * parcels remain safely retryable with their existing idempotency keys.
 */
export async function dispatchParcelsBulk(
  accessToken: string,
  items: BulkDispatchItem[],
): Promise<BulkDispatchResult[]> {
  const results: BulkDispatchResult[] = []

  for (const item of items) {
    try {
      const result = await dispatchParcel(accessToken, {
        p_parcel_id: item.p_parcel_id,
        p_tracking_id: item.p_tracking_id,
        p_idempotency_key: item.p_idempotency_key ?? crypto.randomUUID(),
      })
      results.push({ item, status: 'success', result })
    } catch (error) {
      results.push({
        item,
        status: 'failure',
        error: error instanceof Error ? error.message : 'Bulk dispatch failed for this parcel',
      })
    }
  }

  return results
}
