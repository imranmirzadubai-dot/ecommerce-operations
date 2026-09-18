import { processRto, type ProcessRtoInput, type ProcessRtoResult } from './parcelCommands'

export type BulkRtoItem = Omit<ProcessRtoInput, 'p_idempotency_key'> & {
  p_idempotency_key?: string
}

export type BulkRtoResult = {
  item: BulkRtoItem
  status: 'success' | 'failure'
  result?: ProcessRtoResult[]
  error?: string
}

/**
 * Executes bulk RTO as orchestration around the authoritative individual RTO
 * command. Each parcel remains an independent transaction and failures are
 * reported per parcel so successful work is never rolled back by a later item.
 */
export async function processRtoBulk(
  accessToken: string,
  items: BulkRtoItem[],
): Promise<BulkRtoResult[]> {
  const results: BulkRtoResult[] = []

  for (const item of items) {
    try {
      const result = await processRto(accessToken, {
        p_parcel_id: item.p_parcel_id,
        p_note: item.p_note ?? null,
        p_idempotency_key: item.p_idempotency_key ?? crypto.randomUUID(),
      })
      results.push({ item, status: 'success', result })
    } catch (error) {
      results.push({
        item,
        status: 'failure',
        error: error instanceof Error ? error.message : 'Bulk RTO failed for this parcel',
      })
    }
  }

  return results
}
