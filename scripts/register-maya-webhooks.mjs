// Optional: tell Maya's sandbox to send payment webhooks to the deployed
// maya-webhook Edge Function. Payments still work without this, because the
// return page asks Maya for the result, but webhooks also catch buyers who
// close the tab before coming back.
//
//   npm run maya:webhooks
//
// Needs MAYA_SECRET_KEY and SUPABASE_URL in .env.local. Maya's webhook API only
// takes the secret key; with only a public key, add the webhook in Maya Manager
// (Settings > Webhooks) instead.
const { MAYA_SECRET_KEY, SUPABASE_URL, MAYA_BASE_URL = 'https://pg-sandbox.paymaya.com' } = process.env
if (!MAYA_SECRET_KEY || !SUPABASE_URL) {
  console.error('Set MAYA_SECRET_KEY and SUPABASE_URL in .env.local')
  process.exit(1)
}

const callbackUrl = `${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/maya-webhook`
// Same formats the Edge Functions accept: raw key, its Base64 form, or "Basic ...".
const raw = MAYA_SECRET_KEY.trim()
const auth = /^basic\s+/i.test(raw)
  ? `Basic ${raw.replace(/^basic\s+/i, '')}`
  : /^sk-/.test(raw) ? `Basic ${Buffer.from(`${raw}:`).toString('base64')}` : `Basic ${raw}`
const events = ['PAYMENT_SUCCESS', 'PAYMENT_FAILED', 'PAYMENT_EXPIRED', 'PAYMENT_CANCELLED']

const existing = await fetch(`${MAYA_BASE_URL}/payments/v1/webhooks`, { headers: { Authorization: auth } })
  .then(r => (r.ok ? r.json() : []))
  .catch(() => [])

for (const name of events) {
  const current = Array.isArray(existing) ? existing.find(w => w.name === name) : null
  if (current?.callbackUrl === callbackUrl) {
    console.log(`${name}: already registered`)
    continue
  }
  const res = await fetch(`${MAYA_BASE_URL}/payments/v1/webhooks${current ? `/${current.id}` : ''}`, {
    method: current ? 'PUT' : 'POST',
    headers: { 'Authorization': auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, callbackUrl }),
  })
  const body = await res.json().catch(() => ({}))
  console.log(`${name}: ${res.ok ? (current ? 'updated' : 'registered') : `failed (${res.status}) ${body.message ?? ''}`}`)
}
console.log(`Webhooks point to ${callbackUrl}`)
