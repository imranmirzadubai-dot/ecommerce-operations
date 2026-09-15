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

export type CorrectParcelAllocationInput = {
  p_parcel_item_id: string
  p_corrected_quantity: number
  p_idempotency_key: string
}

export async function correctParcelAllocation(
  accessToken: string,
  input: CorrectParcelAllocationInput,
): Promise<AllocateParcelItemResult[]> {
  return runCommand<AllocateParcelItemResult[]>('correct_parcel_allocation', accessToken, input as unknown as Record<string, unknown>)
}

export type CancelParcelInput = {
  p_parcel_id: string
  p_idempotency_key: string
}

export type CancelParcelResult = {
  parcel_id: string
  parcel_number: string
  state: string
}

export async function cancelParcel(accessToken: string, input: CancelParcelInput): Promise<CancelParcelResult[]> {
  return runCommand<CancelParcelResult[]>('cancel_parcel', accessToken, input as unknown as Record<string, unknown>)
}

export type AssignParcelShipperInput = {
  p_parcel_id: string
  p_shipper_id: string
  p_idempotency_key: string
}

export type AssignParcelShipperResult = {
  parcel_id: string
  parcel_number: string
  shipper_id: string
  shipper_name: string
  state: string
}

export async function assignParcelShipper(
  accessToken: string,
  input: AssignParcelShipperInput,
): Promise<AssignParcelShipperResult[]> {
  return runCommand<AssignParcelShipperResult[]>('assign_parcel_shipper', accessToken, input as unknown as Record<string, unknown>)
}

export type ValidateUniqueTrackingIdInput = {
  p_tracking_id: string
  p_parcel_id?: string | null
}

export type ValidateUniqueTrackingIdResult = {
  valid: boolean
  tracking_id: string
  normalized_tracking_id: string
  conflicting_parcel_id: string | null
}

export async function validateUniqueTrackingId(
  accessToken: string,
  input: ValidateUniqueTrackingIdInput,
): Promise<ValidateUniqueTrackingIdResult[]> {
  return runCommand<ValidateUniqueTrackingIdResult[]>('validate_unique_tracking_id', accessToken, input as unknown as Record<string, unknown>)
}
