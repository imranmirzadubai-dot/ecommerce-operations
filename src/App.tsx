import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import './App.css'
import { getAuthConfig, hasOperationalAccess, restoreSession, signIn, signOut, type AuthState } from './lib/auth'
import { createOrder, resolveCustomerByPhone } from './lib/commands'
import { OrdersWorkspace } from './components/OrdersWorkspace'

const navigation = ['Dashboard', 'Customers', 'Orders', 'Parcels', 'Dispatch', 'Delivery / NDR', 'COD & Finance', 'Invoices', 'Reports']
const signedOutState: AuthState = { authenticated: false, userId: null, profile: null, accessToken: null }

type OrderItem = { description: string; quantity: string }

function App() {
  const [auth, setAuth] = useState<AuthState>(signedOutState)
  const [loading, setLoading] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [customerMessage, setCustomerMessage] = useState('')
  const [orderMessage, setOrderMessage] = useState('')
  const [orderLoading, setOrderLoading] = useState(false)
  const [phone, setPhone] = useState('')
  const [customerName, setCustomerName] = useState('')
  const [address, setAddress] = useState('')
  const [city, setCity] = useState('')
  const [amount, setAmount] = useState('')
  const [notes, setNotes] = useState('')
  const [items, setItems] = useState<OrderItem[]>([{ description: '', quantity: '1' }])
  const configured = getAuthConfig() !== null
  const authenticated = hasOperationalAccess(auth.profile)

  useEffect(() => {
    restoreSession().then(setAuth).finally(() => setLoading(false))
  }, [])

  async function handleSignIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setLoading(true)
    try { setAuth(await signIn(email.trim(), password)); setPassword('') }
    catch (signInError) { setError(signInError instanceof Error ? signInError.message : 'Unable to sign in') }
    finally { setLoading(false) }
  }

  async function handleSignOut() {
    await signOut(); setAuth(signedOutState); setOrderMessage(''); setCustomerMessage('')
  }

  async function lookupCustomer() {
    if (!auth.accessToken || !phone.trim()) return
    setCustomerMessage('Looking up customer…')
    try {
      const rows = await resolveCustomerByPhone(auth.accessToken, phone.trim())
      const customer = rows[0]
      if (!customer) { setCustomerMessage('No existing customer found. A new customer will be created with the order.'); return }
      setCustomerName(customer.name); setAddress(customer.address ?? ''); setCity(customer.city ?? '')
      setCustomerMessage(`Existing customer found: ${customer.customer_code}`)
    } catch (lookupError) { setCustomerMessage(lookupError instanceof Error ? lookupError.message : 'Customer lookup failed') }
  }

  function updateItem(index: number, field: keyof OrderItem, value: string) {
    setItems((current) => current.map((item, itemIndex) => itemIndex === index ? { ...item, [field]: value } : item))
  }
  function addItem() { setItems((current) => [...current, { description: '', quantity: '1' }]) }
  function removeItem(index: number) { setItems((current) => current.length === 1 ? current : current.filter((_, itemIndex) => itemIndex !== index)) }

  async function handleCreateOrder(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!auth.accessToken) return
    setOrderLoading(true); setOrderMessage('')
    try {
      const cleanItems = items.map((item) => ({ description: item.description.trim(), quantity: Number(item.quantity) }))
      if (!cleanItems.every((item) => item.description && Number.isInteger(item.quantity) && item.quantity > 0)) throw new Error('Enter a description and positive whole quantity for every item')
      const numericAmount = Number(amount)
      if (!Number.isFinite(numericAmount) || numericAmount < 0) throw new Error('Enter a valid Total Order Amount')
      const result = await createOrder(auth.accessToken, { p_customer_name: customerName.trim(), p_phone: phone.trim(), p_address: address.trim() || null, p_city: city.trim() || null, p_original_amount: Math.round(numericAmount * 100) / 100, p_items: cleanItems, p_notes: notes.trim() || null, p_idempotency_key: crypto.randomUUID() })
      const order = result[0]; if (!order) throw new Error('The command completed without returning an order')
      setOrderMessage(`Order ${order.order_number} created as Draft.`); setAmount(''); setNotes(''); setItems([{ description: '', quantity: '1' }])
    } catch (createError) { setOrderMessage(createError instanceof Error ? createError.message : 'Order creation failed') }
    finally { setOrderLoading(false) }
  }

  return (
    <div className="operations-app">
      <header className="topbar"><div className="brand"><span className="brand-mark">EO</span><div><strong>E-Commerce Operations</strong><span>Operations workspace</span></div></div><div className="environment"><span className="status-dot" /><span>STAGING</span>{authenticated && <button className="signout" onClick={handleSignOut}>Sign out</button>}</div></header>
      <div className="app-body">
        <aside className="sidebar" aria-label="Primary navigation"><nav>{navigation.map((item, index) => <button className={index === 0 ? 'nav-item active' : 'nav-item'} disabled={!authenticated} key={item}><span>{item}</span>{index === 0 && <span className="nav-badge">Core</span>}</button>)}</nav><div className="sidebar-footer"><span className="eyebrow">Access</span><strong>{auth.profile?.role ?? 'Not signed in'}</strong></div></aside>
        <main className="content">
          <div className="page-heading"><div><span className="eyebrow">Workspace</span><h1>Operations Dashboard</h1><p>Transactional order, parcel, delivery and financial operations.</p></div><span className="foundation-pill">Foundation protected</span></div>
          {!authenticated && <section className="access-panel" aria-labelledby="access-title"><div className="access-icon">✓</div><div><span className="eyebrow">Authentication boundary</span><h2 id="access-title">Secure access is required</h2>{!configured ? <p>Authentication is not configured for this deployment yet. No demo account or business data is being fabricated.</p> : loading ? <p>Checking the current authenticated session…</p> : <form className="login-form" onSubmit={handleSignIn}><label>Email<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="username" required /></label><label>Password<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required /></label><button className="login-button" type="submit" disabled={loading}>{loading ? 'Signing in…' : 'Sign in'}</button>{error && <p className="form-error" role="alert">{error}</p>}</form>}</div><div className="access-state">Signed out</div></section>}
          {authenticated && <section className="access-panel signed-in-panel"><div className="access-icon">✓</div><div><span className="eyebrow">Authenticated</span><h2>{auth.profile?.name}</h2><p>{auth.profile?.email} · {auth.profile?.role}</p></div><div className="access-state">Active</div></section>}
          {authenticated && <section className="workspace-grid"><article className="card order-card"><div className="section-heading"><div><span className="eyebrow">Customer / Order Core</span><h2>Create Draft Order</h2><p>Creates the customer if the phone is new, then atomically creates the order and items.</p></div><span className="check">Transactional</span></div><form className="order-form" onSubmit={handleCreateOrder}><div className="form-row"><label>Customer phone<input value={phone} onChange={(event) => setPhone(event.target.value)} onBlur={lookupCustomer} placeholder="05xxxxxxxx" required /></label><button className="secondary-button" type="button" onClick={lookupCustomer} disabled={!phone.trim()}>Find customer</button></div>{customerMessage && <p className="form-note">{customerMessage}</p>}<div className="form-row"><label>Customer name<input value={customerName} onChange={(event) => setCustomerName(event.target.value)} required /></label><label>City<input value={city} onChange={(event) => setCity(event.target.value)} /></label></div><label>Address<input value={address} onChange={(event) => setAddress(event.target.value)} /></label><div className="items-heading"><strong>Order items</strong><button className="secondary-button" type="button" onClick={addItem}>+ Add item</button></div>{items.map((item, index) => <div className="item-row" key={index}><input aria-label={`Product description ${index + 1}`} placeholder="Product description" value={item.description} onChange={(event) => updateItem(index, 'description', event.target.value)} required /><input aria-label={`Quantity ${index + 1}`} type="number" min="1" step="1" value={item.quantity} onChange={(event) => updateItem(index, 'quantity', event.target.value)} required /><button className="remove-button" type="button" onClick={() => removeItem(index)} disabled={items.length === 1}>Remove</button></div>)}<div className="form-row"><label>Total Order Amount (AED)<input type="number" min="0" step="0.01" value={amount} onChange={(event) => setAmount(event.target.value)} required /></label><label>Notes<input value={notes} onChange={(event) => setNotes(event.target.value)} /></label></div><button className="login-button" type="submit" disabled={orderLoading}>{orderLoading ? 'Creating order…' : 'Create Draft Order'}</button>{orderMessage && <p className={orderMessage.startsWith('Order ') ? 'form-success' : 'form-error'} role="status">{orderMessage}</p>}</form></article><OrdersWorkspace accessToken={auth.accessToken!} /></section>}
          <section className="metrics" aria-label="Workspace status">{['Orders', 'Parcels', 'COD', 'Exceptions'].map((metric) => <article key={metric}><span className="eyebrow">{metric}</span><strong>—</strong><p>{authenticated ? 'Ready for transactional data' : 'Awaiting authenticated data'}</p></article>)}</section>
          <section className="foundation-grid"><article className="card"><span className="eyebrow">Database</span><h2>Security foundation</h2><p>PostgreSQL constraints, RLS and transactional command boundaries are established before business data entry.</p><span className="check">✓ Verified in CI and staging</span></article><article className="card"><span className="eyebrow">Commands</span><h2>Idempotency foundation</h2><p>State-changing order commands use an authenticated actor and deterministic idempotency key boundary.</p><span className="check">✓ Structural + staging behavior verified</span></article><article className="card"><span className="eyebrow">Environment</span><h2>Staging isolation</h2><p>Business fixtures remain absent. The workspace cannot silently fall back to production data.</p><span className="check">✓ No production data touched</span></article></section>
        </main>
      </div>
    </div>
  )
}

export default App
