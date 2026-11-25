import type { CatalogProduct } from '@/lib/catalog'
import type { CartLine } from '@/stores/cart'
import { coverImage, productSelect } from '@/lib/catalog'
import { supabase } from '@/lib/supabase'

// The signed-in shopper's cart, kept in cart_items so the phone app and the
// website share it. RLS limits every call to the caller's own rows.

export function toCartLine(product: CatalogProduct, qty: number): CartLine {
  return {
    productId: product.id,
    qty,
    name: product.name,
    slug: product.slug,
    price: product.price,
    stock: product.stock,
    image: coverImage(product),
    artisan: { id: product.artisan_id, shopName: product.artisan.shop_name, slug: product.artisan.slug },
  }
}

// Lines for products the shopper can still buy, plus the ids of rows whose
// product is gone, hidden or from a shop that is no longer verified.
export async function fetchCartLines(): Promise<{ lines: CartLine[], unavailable: string[] }> {
  const { data, error } = await supabase
    .from('cart_items')
    .select(`product_id, qty, product:products(${productSelect})`)
    .order('created_at')
  if (error) throw error
  const lines: CartLine[] = []
  const unavailable: string[] = []
  for (const row of (data ?? []) as unknown as { product_id: string, qty: number, product: CatalogProduct | null }[]) {
    if (row.product?.is_active && row.product.artisan?.status === 'verified') lines.push(toCartLine(row.product, row.qty))
    else unavailable.push(row.product_id)
  }
  return { lines, unavailable }
}

// Returns the new quantity, clamped to stock by the database.
export async function addToCart(productId: string, qty: number): Promise<number> {
  const { data, error } = await supabase.rpc('add_to_cart', { p_product_id: productId, p_qty: qty })
  if (error) throw error
  return data as number
}

export async function setCartQty(productId: string, qty: number) {
  const { error } = await supabase.from('cart_items').update({ qty }).eq('product_id', productId)
  if (error) throw error
}

export async function removeCartItems(productIds: string[]) {
  if (!productIds.length) return
  const { error } = await supabase.from('cart_items').delete().in('product_id', productIds)
  if (error) throw error
}
