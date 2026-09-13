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
