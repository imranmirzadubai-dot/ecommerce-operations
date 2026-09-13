import { runCommand } from './commands'

export type CreateParcelInput = {
  p_order_id: string
  p_idempotency_key: string
}

export type CreateParcelResult = {
  parcel_id: string
  parcel_number: string
  barcode: string
  order_id: string
  state: string
}

export async function createParcel(accessToken: string, input: CreateParcelInput): Promise<CreateParcelResult[]> {
  return runCommand<CreateParcelResult[]>('create_parcel', accessToken, input as unknown as Record<string, unknown>)
}

export type AllocateParcelItemInput = {
  p_parcel_id: string
  p_order_item_id: string
  p_quantity: number
  p_idempotency_key: string
}

export type AllocateParcelItemResult = {
  parcel_item_id: string
  parcel_id: string
  order_item_id: string
  quantity: number
  allocation_state: string
}

export async function allocateParcelItem(accessToken: string, input: AllocateParcelItemInput): Promise<AllocateParcelItemResult[]> {
  return runCommand<AllocateParcelItemResult[]>('allocate_parcel_item', accessToken, input as unknown as Record<string, unknown>)
}

export type SplitParcelAllocation = {
  parcel_id: string
  quantity: number
}

export type AllocateParcelItemsSplitInput = {
  p_order_item_id: string
  p_allocations: SplitParcelAllocation[]
  p_idempotency_key: string
}

export async function allocateParcelItemsSplit(
  accessToken: string,
  input: AllocateParcelItemsSplitInput,
): Promise<AllocateParcelItemResult[]> {
  return runCommand<AllocateParcelItemResult[]>('allocate_parcel_items', accessToken, input as unknown as Record<string, unknown>)
}
