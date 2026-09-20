import { useEffect, useState } from 'react'
import { downloadExcelWorkbook } from '../lib/excel'

type Props = { selectedOrderIds: string[] }

type ExportRow = {
  order: string
  customer: string
  phone: string
  state: string
  amount: string
  date: string
}

function readVisibleRows(): ExportRow[] {
  return Array.from(document.querySelectorAll<HTMLTableRowElement>('.orders-table tbody tr')).map((row) => {
    const cells = Array.from(row.querySelectorAll<HTMLTableCellElement>('td'))
    return {
      order: cells[0]?.querySelector('strong')?.textContent?.trim() ?? '',
      customer: cells[1]?.querySelector('span')?.textContent?.trim() ?? '',
      phone: cells[1]?.querySelector('small')?.textContent?.trim() ?? '',
      state: cells[2]?.textContent?.trim() ?? '',
      amount: cells[3]?.textContent?.trim() ?? '',
      date: cells[4]?.textContent?.trim() ?? '',
    }
  }).filter((row) => row.order)
}

export function OrderExport({ selectedOrderIds }: Props) {
  const [visibleCount, setVisibleCount] = useState(0)
  useEffect(() => {
    const sync = () => setVisibleCount(document.querySelectorAll('.orders-table tbody tr').length)
    sync()
    const observer = new MutationObserver(sync)
    const workspace = document.querySelector('.orders-workspace')
    if (workspace) observer.observe(workspace, { childList: true, subtree: true })
    return () => observer.disconnect()
  }, [])

  function exportOrders() {
    const rows = readVisibleRows()
    const selected = new Set(selectedOrderIds)
    const exportRows = selected.size ? rows.filter((row) => selected.has(row.order)) : rows
    if (!exportRows.length) return
    const sheetRows = [
      ['Order', 'Customer', 'Phone', 'Lifecycle State', 'Amount (AED)', 'Order Date'],
      ...exportRows.map((row) => [row.order, row.customer, row.phone, row.state, row.amount.replace(/^AED\s*/i, ''), row.date]),
    ]
    downloadExcelWorkbook(`orders-export-${new Date().toISOString().slice(0, 10)}.xlsx`, [{ name: 'Orders', rows: sheetRows }])
  }

  const selectedCount = selectedOrderIds.length
  const label = selectedCount ? `Export ${selectedCount} selected` : 'Export visible orders'
  return <button className="secondary-button" type="button" onClick={exportOrders} disabled={!visibleCount || (selectedCount > 0 && !selectedOrderIds.length)} aria-label="Export orders to Excel">{label} to Excel</button>
}
