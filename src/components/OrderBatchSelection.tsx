import { useEffect, useMemo, useState } from 'react'
import { OrdersWorkspace } from './OrdersWorkspace'
import { OperationalStatusIndicators } from './OperationalStatusIndicators'

type Props = { accessToken: string }

export function OrderBatchSelection({ accessToken }: Props) {
  const [selected, setSelected] = useState<string[]>([])
  const [visibleOrders, setVisibleOrders] = useState<string[]>([])

  useEffect(() => {
    const sync = () => {
      const ids = Array.from(document.querySelectorAll<HTMLElement>('.orders-table tbody tr')).map((row) => row.querySelector('td strong')?.textContent?.trim() ?? '').filter(Boolean)
      setVisibleOrders(ids)
      setSelected((current) => current.filter((id) => ids.includes(id)))
    }
    sync()
    const observer = new MutationObserver(sync)
    const table = document.querySelector('.orders-workspace')
    if (table) observer.observe(table, { childList: true, subtree: true })
    return () => observer.disconnect()
  }, [])

  const allSelected = visibleOrders.length > 0 && visibleOrders.every((id) => selected.includes(id))
  const selectedLabel = useMemo(() => selected.length === 1 ? '1 order selected' : `${selected.length} orders selected`, [selected.length])
  function toggle(id: string) { setSelected((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]) }
  function toggleAll() { setSelected((current) => allSelected ? current.filter((id) => !visibleOrders.includes(id)) : Array.from(new Set([...current, ...visibleOrders]))) }

  return <section className="order-batch-selection" aria-label="Order batch selection">
    <div className="section-heading"><div><span className="eyebrow">Batch Selection</span><strong>{selectedLabel}</strong></div><div className="button-group"><button className="secondary-button" type="button" onClick={toggleAll} disabled={!visibleOrders.length}>{allSelected ? 'Clear visible' : 'Select visible'}</button><button className="secondary-button" type="button" onClick={() => setSelected([])} disabled={!selected.length}>Clear selection</button></div></div>
    <div className="order-batch-selection-list">{visibleOrders.map((id) => <label key={id}><input type="checkbox" checked={selected.includes(id)} onChange={() => toggle(id)} /> {id}</label>)}</div>
    <p className="form-note">Selection is scoped to the currently visible Orders workspace page. Later batch-action tasks will consume this selection.</p>
    <div aria-label="Operational Status"><OperationalStatusIndicators accessToken={accessToken} /></div>
    <OrdersWorkspace accessToken={accessToken} />
  </section>
}
