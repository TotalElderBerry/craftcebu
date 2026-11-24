// Called by the page the buyer lands on after Maya. Asks Maya for the real
// status (the redirect alone proves nothing) and records it on the order.
import { corsHeaders, json } from '../_shared/http.ts'
import { lookupStatus } from '../_shared/maya.ts'
import { adminClient, userClient } from '../_shared/supabase.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const { orderId } = await req.json()
    if (typeof orderId !== 'string') return json({ error: 'orderId is required' }, 400)

    const db = userClient(req)
    const { data: { user } } = await db.auth.getUser()
    if (!user) return json({ error: 'Sign in first' }, 401)

    const { data: order, error } = await db
      .from('orders')
      .select('id, buyer_id, payment_method, payment_status, maya_checkout_id')
      .eq('id', orderId)
      .maybeSingle()
    if (error) throw error
    if (!order || order.buyer_id !== user.id) return json({ error: 'Order not found' }, 404)
    if (order.payment_method !== 'maya' || !order.maya_checkout_id || order.payment_status !== 'unpaid') {
      return json({ paymentStatus: order.payment_status })
    }

    const mayaStatus = await lookupStatus(order.maya_checkout_id, order.id)
    const { data: paymentStatus, error: applyError } = await adminClient().rpc('apply_maya_payment', {
      p_order_id: order.id,
      p_payment_id: order.maya_checkout_id,
      p_maya_status: mayaStatus,
    })
    if (applyError) throw applyError

    return json({ paymentStatus, mayaStatus })
  }
  catch (e) {
    console.error(e)
    return json({ error: e instanceof Error ? e.message : 'Could not check the payment' }, 500)
  }
})
