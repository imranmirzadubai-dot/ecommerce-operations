import { dispatchParcel, type DispatchParcelInput } from './parcelCommands'

export type BulkDispatchItem = Omit<DispatchParcelInput, 'p_idempotency_key'> & {
  p_idempotency_key?: string
}

/**
 * Executes a bulk dispatch as orchestration around the authoritative individual
 * dispatch command. Each parcel remains an independent transaction; one command
 * failure stops the batch so the caller can retry from a known boundary.
 */
export async function dispatchParcelsBulk(
  accessToken: string,
  items: BulkDispatchItem[],
): Promise<void> {
  for (const item of items) {
    await dispatchParcel(accessToken, {
      p_parcel_id: item.p_parcel_id,
      p_tracking_id: item.p_tracking_id,
      p_idempotency_key: item.p_idempotency_key ?? crypto.randomUUID(),
    })
  }
}
