export type CreateOrderInput = {
  p_customer_name: string
  p_phone: string
  p_address: string | null
  p_city: string | null
  p_original_amount: string
  p_items: Array<{ description: string; quantity: number }>
  p_notes?: string | null
  p_idempotency_key: string
}

export type UpdateOrderInput = {
  p_order_id: string
  p_customer_name: string
  p_phone: string
  p_address: string | null
  p_city: string | null
  p_original_amount: string
  p_items: Array<{ description: string; quantity: number }>
  p_notes?: string | null
  p_idempotency_key: string
}

export type ConfirmOrderInput = {
  p_order_id: string
  p_idempotency_key: string
}

export type CreateOrderResult = {
  order_id: string
  order_number: string
  customer_id: string
}

export type UpdateOrderResult = {
  order_id: string
  order_number: string
  lifecycle_state: string
}

export type ConfirmOrderResult = {
  order_id: string
  order_number: string
  lifecycle_state: string
}

export type OrderItemRow = {
  id: string
  line_no: number
  description: string
  quantity: number
}

export type OrderTimelineEvent = {
  id: string
  event_type: string
  event_time: string
  performed_by: string
  notes: string | null
  metadata: Record<string, unknown>
  parcel_id: string | null
}

export type OrderListRow = {
  id: string
  order_number: string
  lifecycle_state: string
  original_amount: number
  notes: string | null
  created_at: string
  updated_at: string
  customers: { id: string; name: string; phone: string; address: string | null; city: string | null } | null
  order_items: OrderItemRow[]
}

export type CustomerHistoryRow = {
  id: string
  order_number: string
  order_date: string
  lifecycle_state: string
  original_amount: number
}

type CommandError = { message?: string; error?: string; details?: string }
type ListOrdersOptions = { page?: number; pageSize?: number; search?: string; lifecycleState?: string; parcelState?: string; codState?: string }
export type PaginatedOrders = { orders: OrderListRow[]; page: number; pageSize: number; hasMore: boolean; search: string }

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

export async function updateOrder(accessToken: string, input: UpdateOrderInput): Promise<UpdateOrderResult[]> {
  return runCommand<UpdateOrderResult[]>('update_order', accessToken, input as unknown as Record<string, unknown>)
}

export async function confirmOrder(accessToken: string, input: ConfirmOrderInput): Promise<ConfirmOrderResult[]> {
  return runCommand<ConfirmOrderResult[]>('confirm_order', accessToken, input as unknown as Record<string, unknown>)
}

export async function listOrders(accessToken: string, options: ListOrdersOptions = {}): Promise<PaginatedOrders> {
  const page = Math.max(1, Math.floor(options.page ?? 1))
  const pageSize = Math.min(100, Math.max(1, Math.floor(options.pageSize ?? 25)))
  const search = (options.search ?? '').trim()
  const query = new URLSearchParams({ page: String(page), page_size: String(pageSize) })
  if (search) query.set('search', search)
  if (options.lifecycleState) query.set('lifecycle_state', options.lifecycleState)
  if (options.parcelState) query.set('parcel_state', options.parcelState)
  if (options.codState) query.set('cod_state', options.codState)
  const response = await fetch(`/api/orders?${query.toString()}`, {
    headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = (await response.json().catch(() => null)) as OrderListRow[] | CommandError | null
  if (!response.ok) {
    const error = payload as CommandError | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Orders request failed (${response.status})`)
  }
  return {
    orders: Array.isArray(payload) ? payload : [],
    page,
    pageSize,
    hasMore: response.headers.get('X-Has-More') === 'true',
    search,
  }
}

export async function getOrderTimeline(accessToken: string, orderId: string): Promise<OrderTimelineEvent[]> {
  const response = await fetch(`/api/orders/${encodeURIComponent(orderId)}/timeline`, {
    headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = (await response.json().catch(() => null)) as OrderTimelineEvent[] | CommandError | null
  if (!response.ok) {
    const error = payload as CommandError | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Order timeline request failed (${response.status})`)
  }
  return (payload ?? []) as OrderTimelineEvent[]
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
