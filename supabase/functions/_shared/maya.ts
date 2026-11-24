// Maya Checkout API (https://developers.maya.ph), called with HTTP Basic auth.
// The public key creates checkouts and can read a payment's status; the secret
// key (optional) reads full payment records. Both stay in Supabase secrets.
const BASE_URL = Deno.env.get('MAYA_BASE_URL') ?? 'https://pg-sandbox.paymaya.com'

// A key may be stored as the raw key ("pk-..."), its Base64 form ("cGst...="),
// or the whole header value ("Basic cGst...="); all become one header value.
export function basicAuth(value: string) {
  const v = value.trim()
  if (/^basic\s+/i.test(v)) return `Basic ${v.replace(/^basic\s+/i, '')}`
  if (/^(pk|sk)-/.test(v)) return `Basic ${btoa(`${v}:`)}`
  try {
    // Base64 of "key:" decodes to something ending in a colon.
    if (atob(v).endsWith(':')) return `Basic ${v}`
  }
  catch {
    // Not Base64; fall through and treat it as a raw key.
  }
  return `Basic ${btoa(`${v}:`)}`
}

const publicAuth = () => {
  const value = Deno.env.get('MAYA_PUBLIC_KEY')
  if (!value) throw new Error('MAYA_PUBLIC_KEY is not set')
  return basicAuth(value)
}
const secretAuth = () => {
  const value = Deno.env.get('MAYA_SECRET_KEY')
  return value ? basicAuth(value) : null
}

export async function createCheckout(body: unknown) {
  const res = await fetch(`${BASE_URL}/checkout/v1/checkouts`, {
    method: 'POST',
    headers: { 'Authorization': publicAuth(), 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(`Maya checkout failed (${res.status}): ${data.message ?? JSON.stringify(data)}`)
  return data as { checkoutId: string, redirectUrl: string }
}

export interface MayaPayment {
  id: string
  status?: string
  paymentStatus?: string
  requestReferenceNumber?: string
}

// The docs name the field `status` on reads and `paymentStatus` on webhooks.
export const statusOf = (p: MayaPayment) => p.status ?? p.paymentStatus ?? 'UNKNOWN'

async function getJson(path: string, auth: string) {
  const res = await fetch(`${BASE_URL}${path}`, { headers: { Authorization: auth } })
  if (res.status === 404) return null
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(`Maya lookup failed (${res.status}): ${data.message ?? JSON.stringify(data)}`)
  return data
}

// Full payment record (secret key). A checkout's id is also its payment id.
export function getPayment(paymentId: string) {
  const auth = secretAuth()
  if (!auth) return Promise.resolve(null)
  return getJson(`/payments/v1/payments/${encodeURIComponent(paymentId)}`, auth) as Promise<MayaPayment | null>
}

// Just { id, status }; Maya documents this one for the public key.
export function getPaymentStatus(paymentId: string) {
  return getJson(`/payments/v1/payments/${encodeURIComponent(paymentId)}/status`, secretAuth() ?? publicAuth()) as Promise<MayaPayment | null>
}

// Every payment made with one request reference number (our order id).
async function getPaymentsByRrn(rrn: string) {
  const auth = secretAuth()
  if (!auth) return []
  return ((await getJson(`/payments/v1/payment-rrns/${encodeURIComponent(rrn)}`, auth)) ?? []) as MayaPayment[]
}

const PAID = ['PAYMENT_SUCCESS', 'AUTHORIZED', 'CAPTURED']

// The current status of an order's checkout. Tries the full record (secret
// key), then the status endpoint (works with only the public key), then every
// payment under the order's reference number.
export async function lookupStatus(checkoutId: string, orderId: string) {
  const direct = (await getPayment(checkoutId)) ?? (await getPaymentStatus(checkoutId))
  if (direct) return statusOf(direct)
  const all = await getPaymentsByRrn(orderId)
  const match = all.find(p => p.id === checkoutId)
  if (match) return statusOf(match)
  if (all.some(p => PAID.includes(statusOf(p)))) return 'PAYMENT_SUCCESS'
  return 'PENDING_PAYMENT'
}
