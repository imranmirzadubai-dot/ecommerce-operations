import { runCommand } from './commands'

export type CreateFinancialAdjustmentInput = {
  p_order_id: string
  p_adjustment_type: string
  p_delta_amount: number
  p_reason: string
  p_parcel_id: string | null
  p_cod_receipt_id: string | null
  p_idempotency_key: string
}

export type CreateFinancialAdjustmentResult = {
  financial_adjustment_id: string
  order_id: string
  adjustment_type: string
  delta_amount: number
  reason: string
  parcel_id: string | null
  cod_receipt_id: string | null
}

export async function createFinancialAdjustment(
  accessToken: string,
  input: CreateFinancialAdjustmentInput,
): Promise<CreateFinancialAdjustmentResult[]> {
  return runCommand<CreateFinancialAdjustmentResult[]>(
    'create_financial_adjustment',
    accessToken,
    input as unknown as Record<string, unknown>,
  )
}
