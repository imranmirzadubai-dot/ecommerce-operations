import { downloadExcelWorkbook } from '../lib/excel'
import type { OrderListRow } from '../lib/commands'

type Props = { orders: OrderListRow[]; selectedOrderIds: string[] }

export function OrderExport({ orders, selectedOrderIds }: Props) {
  function exportOrders() {
    const selected = new Set(selectedOrderIds)
    const exportOrders = selected.size ? orders.filter((order) => selected.has(order.order_number)) : orders
    if (!exportOrders.length) return
    const sheetRows = [
      ['Order', 'Customer', 'Phone', 'Lifecycle State', 'Amount (AED)', 'Order Date'],
      ...exportOrders.map((order) => [
        order.order_number,
        order.customers?.name ?? '',
        order.customers?.phone ?? '',
        order.lifecycle_state,
        Number(order.original_amount).toFixed(2),
        order.order_date,
      ]),
    ]
    downloadExcelWorkbook(`orders-export-${new Date().toISOString().slice(0, 10)}.xlsx`, [{ name: 'Orders', rows: sheetRows }])
  }

  const selectedCount = selectedOrderIds.length
  const selectedVisibleCount = selectedCount ? orders.filter((order) => selectedOrderIds.includes(order.order_number)).length : orders.length
  const label = selectedCount ? `Export ${selectedCount} selected` : 'Export visible orders'
  return <button className="secondary-button" type="button" onClick={exportOrders} disabled={!orders.length || (selectedCount > 0 && !selectedVisibleCount)} aria-label="Export orders to Excel">{label} to Excel</button>
}
