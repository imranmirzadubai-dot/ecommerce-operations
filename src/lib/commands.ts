export type CreateOrderInput = {
  p_customer_name: string
  p_phone: string
  p_address: string | null
  p_city: string | null
  p_original_amount: number
  p_items: Array<{ description: string; quantity: number }>
  p_notes?: string | null
  p_idempotency_key: string
}

export type CreateOrderResult = {
  order_id: string
  order_number: string
  customer_id: string
}

export type OrderListRow = {
  id: string
  order_number: string
  lifecycle_state: string
  original_amount: number
  created_at: string
  updated_at: string
  customers: { name: string; phone: string } | null
}

export type CustomerHistoryRow = {
  id: string
  order_number: string
  order_date: string
  lifecycle_state: string
  original_amount: number
}

type CommandError = { message?: string; error?: string; details?: string }

export async function runCommand<T>(command: string, accessToken: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(`/api/commands/${encodeURIComponent(command)}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(body),
  })
  const payload = (await response.json().catch(() => null)) as T | CommandError | null
  if (!response.ok) {
    const error = payload as CommandError | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Command failed (${response.status})`)
  }
  return payload as T
}

export async function resolveCustomerByPhone(accessToken: string, phone: string) {
  return runCommand<{ customer_id: string; customer_code: string; name: string; phone: string; address: string | null; city: string | null }[]>(
    'resolve_customer_by_phone', accessToken, { p_phone: phone },
  )
}

export async function createOrder(accessToken: string, input: CreateOrderInput): Promise<CreateOrderResult[]> {
  return runCommand<CreateOrderResult[]>('create_order', accessToken, input as unknown as Record<string, unknown>)
}

export async function listOrders(accessToken: string): Promise<OrderListRow[]> {
  const response = await fetch('/api/orders', {
    headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = (await response.json().catch(() => null)) as OrderListRow[] | CommandError | null
  if (!response.ok) {
    const error = payload as CommandError | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Orders request failed (${response.status})`)
  }
  return (payload ?? []) as OrderListRow[]
}

export async function getCustomerHistory(accessToken: string, customerId: string): Promise<CustomerHistoryRow[]> {
  const response = await fetch(`/api/customers/${encodeURIComponent(customerId)}/history`, {
    headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = (await response.json().catch(() => null)) as CustomerHistoryRow[] | CommandError | null
  if (!response.ok) {
    const error = payload as CommandError | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Customer history request failed (${response.status})`)
  }
  return (payload ?? []) as CustomerHistoryRow[]
}
