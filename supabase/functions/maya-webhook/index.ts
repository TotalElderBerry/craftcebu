// Receives Maya's PAYMENT_* webhooks. Maya doesn't sign webhooks, so the body
// is only used to find the order; the payment's status is re-read from Maya
// before the order changes, and the payment id must be the checkout this order
// started. Deploy with --no-verify-jwt.
import { getPayment, lookupStatus } from '../_shared/maya.ts'
import { adminClient } from '../_shared/supabase.ts'

const ok = () => new Response('ok', { status: 200 })
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  let paymentId: string | undefined
  let reference: string | undefined
  try {
    const body = await req.json()
    paymentId = typeof body?.id === 'string' ? body.id : undefined
    reference = typeof body?.requestReferenceNumber === 'string' ? body.requestReferenceNumber : undefined
  }
  catch {
    return ok()
  }
  if (!paymentId) return ok()

  try {
    // Prefer Maya's own record of the reference (needs the secret key).
    const orderId = (await getPayment(paymentId))?.requestReferenceNumber ?? reference
    if (!orderId || !UUID.test(orderId)) return ok()

    const db = adminClient()
    const { data: order } = await db.from('orders').select('id, maya_checkout_id').eq('id', orderId).maybeSingle()
    // Ignore payments for an older checkout of this order or for other systems.
    if (!order || order.maya_checkout_id !== paymentId) return ok()

    const { error } = await db.rpc('apply_maya_payment', {
      p_order_id: order.id,
      p_payment_id: paymentId,
      p_maya_status: await lookupStatus(paymentId, order.id),
    })
    if (error) throw error
    return ok()
  }
  catch (e) {
    // A non-200 makes Maya retry later (up to 3 more times).
    console.error(e)
    return new Response('retry', { status: 500 })
  }
})
