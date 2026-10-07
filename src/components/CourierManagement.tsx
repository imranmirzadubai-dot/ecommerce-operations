import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { canAdministerUsers, type Profile } from '../lib/auth'
import { createCourier, listCouriers, setCourierActive, updateCourier, type Courier } from '../lib/commands'
import '../styles/admin-responsive.css'

type FormState = {
  name: string
  contact_name: string
  contact_phone: string
  contact_email: string
  address: string
  notes: string
}

const emptyForm: FormState = {
  name: '',
  contact_name: '',
  contact_phone: '',
  contact_email: '',
  address: '',
  notes: '',
}

function toForm(courier: Courier): FormState {
  return {
    name: courier.name,
    contact_name: courier.contact_name ?? '',
    contact_phone: courier.contact_phone ?? '',
    contact_email: courier.contact_email ?? '',
    address: courier.address ?? '',
    notes: courier.notes ?? '',
  }
}

function normalizeCommandCourier(row: Courier & { courier_id?: string }): Courier {
  return { ...row, id: row.id || row.courier_id || '' }
}

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error ? error.message : fallback
}

export function CourierManagement({
  accessToken,
  profile,
  onOpenParcels,
}: {
  accessToken: string
  profile: Profile | null
  onOpenParcels: () => void
}) {
  const [couriers, setCouriers] = useState<Courier[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(emptyForm)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all')
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  const canAdmin = canAdministerUsers(profile)

  async function refresh() {
    if (!canAdmin) return
    setLoading(true)
    setError('')
    try {
      setCouriers(await listCouriers(accessToken))
    } catch (loadError) {
      setError(errorMessage(loadError, 'Unable to load couriers'))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    const timer = window.setTimeout(() => { void refresh() }, 0)
    return () => window.clearTimeout(timer)
    // refresh is intentionally scoped to the current authenticated admin.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [accessToken, canAdmin])

  const visibleCouriers = useMemo(() => {
    const term = search.trim().toLowerCase()
    return couriers.filter((courier) => {
      const matchesStatus = statusFilter === 'all' || (statusFilter === 'active' ? courier.active : !courier.active)
      if (!matchesStatus) return false
      if (!term) return true
      return [courier.courier_code, courier.name, courier.contact_name, courier.contact_phone, courier.contact_email]
        .some((value) => value?.toLowerCase().includes(term))
    })
  }, [couriers, search, statusFilter])

  function setField(field: keyof FormState, value: string) {
    setForm((current) => ({ ...current, [field]: value }))
  }

  function startCreate() {
    setEditingId(null)
    setForm(emptyForm)
    setMessage('')
    setError('')
  }

  function startEdit(courier: Courier) {
    setEditingId(courier.id)
    setForm(toForm(courier))
    setMessage('')
    setError('')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaving(true)
    setMessage('')
    setError('')
    try {
      const payload = {
        p_name: form.name.trim(),
        p_contact_name: form.contact_name.trim() || null,
        p_contact_phone: form.contact_phone.trim() || null,
        p_contact_email: form.contact_email.trim() || null,
        p_address: form.address.trim() || null,
        p_notes: form.notes.trim() || null,
        p_idempotency_key: crypto.randomUUID(),
      }

      if (!payload.p_name) throw new Error('Courier name is required')

      const result = editingId
        ? await updateCourier(accessToken, { ...payload, p_courier_id: editingId })
        : await createCourier(accessToken, payload)

      const row = result[0]
      if (!row) throw new Error('The courier command completed without returning a courier')

      const normalized = normalizeCommandCourier(row)
      if (!normalized.id) throw new Error('The courier command returned an invalid courier identifier')

      setCouriers((current) => {
        const existing = current.some((item) => item.id === normalized.id)
        return existing ? current.map((item) => item.id === normalized.id ? normalized : item) : [...current, normalized]
      })
      setEditingId(null)
      setForm(emptyForm)
      setMessage(editingId ? `Courier ${normalized.courier_code} updated.` : `Courier ${normalized.courier_code} created successfully.`)
    } catch (saveError) {
      setError(errorMessage(saveError, editingId ? 'Unable to update courier' : 'Unable to create courier'))
    } finally {
      setSaving(false)
    }
  }

  async function toggleActive(courier: Courier) {
    setSaving(true)
    setMessage('')
    setError('')
    try {
      const result = await setCourierActive(accessToken, {
        p_courier_id: courier.id,
        p_active: !courier.active,
        p_idempotency_key: crypto.randomUUID(),
      })
      const row = result[0]
      if (!row) throw new Error('The courier status command completed without returning a courier')
      const normalized = normalizeCommandCourier(row)
      setCouriers((current) => current.map((item) => item.id === courier.id ? normalized : item))
      setMessage(`${normalized.courier_code} is now ${normalized.active ? 'active' : 'inactive'}.`)
    } catch (statusError) {
      setError(errorMessage(statusError, 'Unable to change courier status'))
    } finally {
      setSaving(false)
    }
  }

  if (!canAdmin) return null

  return <section className="card admin-users-card" aria-labelledby="courier-management-title">
    <div className="section-heading">
      <div>
        <span className="eyebrow">Administration</span>
        <h2 id="courier-management-title">Courier management</h2>
        <p>Create, edit and activate/deactivate courier master records. Courier codes are generated by the database and cannot be edited.</p>
      </div>
      <span className="check">Admin only</span>
    </div>

    <form className="admin-user-form" onSubmit={handleSubmit}>
      <label>Courier name<input value={form.name} onChange={(event) => setField('name', event.target.value)} maxLength={200} required placeholder="e.g. Emirates Post" /></label>
      <label>Contact name<input value={form.contact_name} onChange={(event) => setField('contact_name', event.target.value)} maxLength={200} /></label>
      <label>Contact phone<input value={form.contact_phone} onChange={(event) => setField('contact_phone', event.target.value)} maxLength={50} /></label>
      <label>Contact email<input type="email" value={form.contact_email} onChange={(event) => setField('contact_email', event.target.value)} maxLength={320} /></label>
      <label>Address<input value={form.address} onChange={(event) => setField('address', event.target.value)} maxLength={500} /></label>
      <label>Notes<input value={form.notes} onChange={(event) => setField('notes', event.target.value)} maxLength={2000} /></label>
      <div className="admin-form-actions">
        <button className="login-button" type="submit" disabled={saving}>{saving ? (editingId ? 'Saving…' : 'Creating…') : (editingId ? 'Save courier' : 'Create courier')}</button>
        {editingId && <button className="secondary-button" type="button" onClick={startCreate} disabled={saving}>Cancel edit</button>}
      </div>
    </form>

    {message && <p className="form-success" role="status">{message}</p>}
    {error && <p className="form-error" role="alert">{error}</p>}

    <div className="section-heading" style={{ marginTop: 20 }}>
      <div>
        <span className="eyebrow">Courier master</span>
        <strong>{couriers.length} courier{couriers.length === 1 ? '' : 's'}</strong>
        <p>Assignment remains parcel-level. Use Parcels to assign or reassign a courier to a Prepared parcel.</p>
      </div>
      <div className="heading-actions">
        <button className="secondary-button" type="button" onClick={onOpenParcels}>Open Parcels</button>
        <button className="secondary-button" type="button" onClick={() => void refresh()} disabled={loading || saving}>{loading ? 'Refreshing…' : 'Refresh'}</button>
      </div>
    </div>

    <div className="admin-user-form" style={{ marginBottom: 16 }}>
      <label>Search<input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Code, name, phone or email" /></label>
      <label>Status<select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as typeof statusFilter)}><option value="all">All</option><option value="active">Active</option><option value="inactive">Inactive</option></select></label>
    </div>

    <div className="orders-table-wrap admin-users-table-wrap">
      <table className="orders-table">
        <thead><tr><th>Courier</th><th>Contact</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan={4}>Loading couriers…</td></tr>}
          {!loading && visibleCouriers.map((courier) => <tr key={courier.id}>
            <td><strong>{courier.courier_code}</strong><span>{courier.name}</span></td>
            <td><span>{courier.contact_name || '—'}</span><small>{courier.contact_phone || courier.contact_email || 'No contact details'}</small></td>
            <td><span className="state-pill">{courier.active ? 'Active' : 'Inactive'}</span></td>
            <td><div className="courier-actions"><button className="secondary-button" type="button" onClick={() => startEdit(courier)} disabled={saving}>Edit</button><button className="secondary-button" type="button" onClick={() => void toggleActive(courier)} disabled={saving}>{courier.active ? 'Deactivate' : 'Activate'}</button></div></td>
          </tr>)}
          {!loading && visibleCouriers.length === 0 && <tr><td colSpan={4}>{couriers.length === 0 ? 'No couriers found. Create the first courier above.' : 'No couriers match the current filters.'}</td></tr>}
        </tbody>
      </table>
    </div>
  </section>
}
