import { runCommand } from './commands'

export type RecordCodReceiptInput = {
  p_cod_obligation_id: string
  p_parcel_id: string
  p_received_amount: string
  p_idempotency_key: string
}

export type RecordCodReceiptResult = {
  cod_receipt_id: string
  cod_obligation_id: string
  parcel_id: string
  expected_amount_snapshot: number
  received_amount: number
  state: string
  received_at: string
  received_by: string
}

export async function recordCodReceipt(
  accessToken: string,
  input: RecordCodReceiptInput,
): Promise<RecordCodReceiptResult[]> {
  return runCommand<RecordCodReceiptResult[]>(
    'record_cod_receipt',
    accessToken,
    input as unknown as Record<string, unknown>,
  )
}
