import { runCommand } from './commands'

export type ResolveCodExceptionInput = {
  p_cod_receipt_id: string
  p_reason: string
  p_idempotency_key: string
}

export type ResolveCodExceptionResult = {
  financial_adjustment_id: string
  cod_receipt_id: string
  cod_obligation_id: string
  parcel_id: string
  delta_amount: number
  obligation_state: string
}

export async function resolveCodException(
  accessToken: string,
  input: ResolveCodExceptionInput,
): Promise<ResolveCodExceptionResult[]> {
  return runCommand<ResolveCodExceptionResult[]>(
    'resolve_cod_exception',
    accessToken,
    input as unknown as Record<string, unknown>,
  )
}
