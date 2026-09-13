import { useEffect, useState } from 'react'

type Props = { selectedOrderIds: string[] }

type ExportRow = {
  order: string
  customer: string
  phone: string
  state: string
  amount: string
  date: string
}

function csvCell(value: string) {
  return `"${value.replace(/"/g, '""')}"`
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

function downloadCsv(rows: ExportRow[]) {
  const header = ['Order ID', 'Customer', 'Phone', 'Lifecycle State', 'Amount', 'Order Date']
  const body = rows.map((row) => [row.order, row.customer, row.phone, row.state, row.amount, row.date].map(csvCell).join(','))
  const csv = `\uFEFF${[header.map(csvCell).join(','), ...body].join('\r\n')}\r\n`
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = `orders-export-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(url)
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
    downloadCsv(exportRows)
  }

  const selectedCount = selectedOrderIds.length
  const label = selectedCount ? `Export ${selectedCount} selected` : 'Export visible orders'
  return <button className="secondary-button" type="button" onClick={exportOrders} disabled={!visibleCount || (selectedCount > 0 && !selectedOrderIds.length)} aria-label="Export orders">{label}</button>
}
