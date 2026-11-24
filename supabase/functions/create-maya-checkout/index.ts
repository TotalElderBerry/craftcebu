// Starts a Maya checkout for one of the signed-in buyer's unpaid Maya orders
// and returns the URL of Maya's payment page.
import { corsHeaders, json } from '../_shared/http.ts'
import { createCheckout } from '../_shared/maya.ts'
import { adminClient, userClient } from '../_shared/supabase.ts'

const SITE_URL = (Deno.env.get('SITE_URL') ?? 'http://localhost:5173').replace(/\/$/, '')
const money = (n: number) => Number(n).toFixed(2)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const { orderId } = await req.json()
    if (typeof orderId !== 'string') return json({ error: 'orderId is required' }, 400)

    const db = userClient(req)
    const { data: { user } } = await db.auth.getUser()
    if (!user) return json({ error: 'Sign in first' }, 401)

    // Read as the user: RLS only returns the order if it's theirs to see.
    const { data: order, error } = await db
      .from('orders')
      .select('id, buyer_id, total, payment_method, payment_status, ship_recipient, ship_phone, shops:order_shops(status, shipping_fee, artisan:artisans(shop_name), items:order_items(product_name, qty, unit_price))')
      .eq('id', orderId)
      .maybeSingle()
    if (error) throw error
    if (!order || order.buyer_id !== user.id) return json({ error: 'Order not found' }, 404)
    if (order.payment_method !== 'maya') return json({ error: 'This order isn\'t paid with Maya' }, 400)
    if (order.payment_status !== 'unpaid') return json({ error: 'This order no longer needs payment' }, 400)

    const shops = (order.shops ?? []).filter((s: { status: string }) => s.status !== 'cancelled')
    if (!shops.length) return json({ error: 'This order was cancelled' }, 400)

    const items = shops.flatMap((s: any) => [
      ...s.items.map((i: any) => ({
        name: i.product_name,
        quantity: String(i.qty),
        amount: { value: money(i.unit_price) },
        totalAmount: { value: money(i.unit_price * i.qty) },
      })),
      {
        name: `Shipping from ${s.artisan?.shop_name ?? 'shop'}`,
        quantity: '1',
        amount: { value: money(s.shipping_fee) },
        totalAmount: { value: money(s.shipping_fee) },
      },
    ])
    const shipping = shops.reduce((sum: number, s: any) => sum + Number(s.shipping_fee), 0)
    const [firstName, ...rest] = String(order.ship_recipient).trim().split(/\s+/)
    const returnUrl = (result: string) => `${SITE_URL}/pay/maya/return?order=${order.id}&result=${result}`

    const checkout = await createCheckout({
      totalAmount: {
        value: Number(order.total),
        currency: 'PHP',
        details: { subtotal: money(Number(order.total) - shipping), shippingFee: money(shipping) },
      },
      buyer: {
        firstName,
        lastName: rest.join(' ') || firstName,
        contact: { phone: order.ship_phone, email: user.email },
      },
      items,
      redirectUrl: { success: returnUrl('success'), failure: returnUrl('failure'), cancel: returnUrl('cancel') },
      // Our order id ties every Maya payment back to this order.
      requestReferenceNumber: order.id,
    })

    const { error: saveError } = await adminClient()
      .from('orders')
      .update({ maya_checkout_id: checkout.checkoutId })
      .eq('id', order.id)
    if (saveError) throw saveError

    return json({ redirectUrl: checkout.redirectUrl })
  }
  catch (e) {
    console.error(e)
    return json({ error: e instanceof Error ? e.message : 'Could not start the Maya payment' }, 500)
  }
})
