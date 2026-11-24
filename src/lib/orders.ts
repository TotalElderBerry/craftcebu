import type { Address, PaymentMethod, PaymentStatus, ShopOrderStatus } from '@/types/database'
import { supabase } from '@/lib/supabase'

// --- Addresses ---------------------------------------------------------------

export async function fetchAddresses(userId: string) {
  const { data, error } = await supabase
    .from('addresses')
    .select('*')
    .eq('profile_id', userId)
    .order('is_default', { ascending: false })
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as Address[]
}

export type AddressInput = Pick<Address, 'recipient' | 'phone' | 'street' | 'barangay' | 'city' | 'province'>

export async function addAddress(userId: string, input: AddressInput, makeDefault: boolean) {
  if (makeDefault) await supabase.from('addresses').update({ is_default: false }).eq('profile_id', userId)
  const { data, error } = await supabase
    .from('addresses')
    .insert({ ...input, profile_id: userId, is_default: makeDefault })
    .select('*')
    .single()
  if (error) throw error
  return data as Address
}

// --- Buyer orders ------------------------------------------------------------

export async function placeOrder(items: { product_id: string, qty: number }[], addressId: string, method: PaymentMethod) {
  const { data, error } = await supabase.rpc('place_order', {
    p_items: items,
    p_address_id: addressId,
    p_payment_method: method,
  })
  if (error) throw error
  return data as string
}

export async function mockPay(orderId: string, success: boolean) {
  const { error } = await supabase.rpc('mock_pay_order', { p_order_id: orderId, p_success: success })
  if (error) throw error
}

export async function cancelOrder(orderId: string) {
  const { error } = await supabase.rpc('cancel_order', { p_order_id: orderId })
  if (error) throw error
}

export interface OrderItemRow {
  id: string
  product_id: string | null
  product_name: string
  qty: number
  unit_price: number
  product: { slug: string, images: { url: string, sort_order: number }[] } | null
}

export interface ShopOrderRow {
  id: string
  subtotal: number
  shipping_fee: number
  status: ShopOrderStatus
  shipped_at: string | null
  delivered_at: string | null
  artisan: { shop_name: string, slug: string } | null
  items: OrderItemRow[]
}

export interface OrderRow {
  id: string
  created_at: string
  total: number
  payment_method: PaymentMethod
  payment_status: PaymentStatus
  ship_recipient: string
  ship_phone: string
  ship_address: string
  shops: ShopOrderRow[]
}

const orderSelect = `
  id, created_at, total, payment_method, payment_status, ship_recipient, ship_phone, ship_address,
  shops:order_shops(
    id, subtotal, shipping_fee, status, shipped_at, delivered_at,
    artisan:artisans(shop_name, slug),
    items:order_items(id, product_id, product_name, qty, unit_price, product:products(slug, images:product_images(url, sort_order)))
  )
`

export async function fetchMyOrders(userId: string) {
  const { data, error } = await supabase
    .from('orders')
    .select(orderSelect)
    .eq('buyer_id', userId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as unknown as OrderRow[]
}

export async function fetchOrder(orderId: string) {
  const { data, error } = await supabase.from('orders').select(orderSelect).eq('id', orderId).maybeSingle()
  if (error) throw error
  return data as unknown as OrderRow | null
}

// Where a buyer's shop order stands, in Shopee's "My Purchases" terms.
export type PurchaseStage = 'to-pay' | 'to-ship' | 'to-receive' | 'completed' | 'cancelled'

export function stageOf(order: Pick<OrderRow, 'payment_method' | 'payment_status'>, shop: Pick<ShopOrderRow, 'status'>): PurchaseStage {
  if (shop.status === 'cancelled') return 'cancelled'
  if (shop.status === 'delivered') return 'completed'
  if (shop.status === 'shipped') return 'to-receive'
  if (order.payment_method !== 'cod' && order.payment_status !== 'paid') return 'to-pay'
  return 'to-ship'
}

export const stageLabels: Record<PurchaseStage, string> = {
  'to-pay': 'To Pay',
  'to-ship': 'To Ship',
  'to-receive': 'To Receive',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
}

export const paymentLabels: Record<PaymentMethod, string> = {
  cod: 'Cash on delivery',
  mock: 'Demo payment',
  maya: 'Maya',
}

export const shortId = (id: string) => id.slice(0, 8).toUpperCase()

// --- Seller orders -----------------------------------------------------------

export interface SellerOrderRow {
  id: string
  subtotal: number
  shipping_fee: number
  commission: number
  status: ShopOrderStatus
  shipped_at: string | null
  delivered_at: string | null
  order: Pick<OrderRow, 'id' | 'created_at' | 'payment_method' | 'payment_status' | 'ship_recipient' | 'ship_phone' | 'ship_address'>
  items: Pick<OrderItemRow, 'id' | 'product_name' | 'qty' | 'unit_price'>[]
}

export async function fetchShopOrders(artisanId: string) {
  const { data, error } = await supabase
    .from('order_shops')
    .select(`
      id, subtotal, shipping_fee, commission, status, shipped_at, delivered_at,
      order:orders(id, created_at, payment_method, payment_status, ship_recipient, ship_phone, ship_address),
      items:order_items(id, product_name, qty, unit_price)
    `)
    .eq('artisan_id', artisanId)
  if (error) throw error
  const rows = (data ?? []) as unknown as SellerOrderRow[]
  return rows.sort((a, b) => b.order.created_at.localeCompare(a.order.created_at))
}

export async function updateShopOrderStatus(orderShopId: string, status: ShopOrderStatus) {
  const { error } = await supabase.rpc('update_shop_order_status', { p_order_shop_id: orderShopId, p_status: status })
  if (error) throw error
}

// --- Maya ----------------------------------------------------------------------

// Edge Function errors carry their JSON body on `context`; surface its message.
async function functionError(error: unknown): Promise<Error> {
  const context = (error as { context?: Response }).context
  if (context && typeof context.json === 'function') {
    const body = await context.json().catch(() => null)
    if (body?.error) return new Error(body.error)
  }
  return error instanceof Error ? error : new Error('Something went wrong')
}

// Returns the URL of Maya's payment page for this order.
export async function startMayaCheckout(orderId: string) {
  const { data, error } = await supabase.functions.invoke('create-maya-checkout', { body: { orderId } })
  if (error) throw await functionError(error)
  return data.redirectUrl as string
}

export async function verifyMayaPayment(orderId: string) {
  const { data, error } = await supabase.functions.invoke('verify-maya-payment', { body: { orderId } })
  if (error) throw await functionError(error)
  return data as { paymentStatus: PaymentStatus, mayaStatus?: string }
}
