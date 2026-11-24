import type { ArtisanStatus, Category, Town, UserRole } from '@/types/database'
import { supabase } from '@/lib/supabase'

const must = <T>({ data, error }: { data: T, error: unknown }) => {
  if (error) throw error
  return data
}

// --- Artisans -----------------------------------------------------------------

export interface AdminArtisan {
  id: string
  shop_name: string
  slug: string
  status: ArtisanStatus
  photo_url: string | null
  craft_since: number | null
  created_at: string
  verified_at: string | null
  town: { name: string } | null
  owner: { full_name: string, email: string | null } | null
  products: { count: number }[]
}

export async function fetchAllArtisans() {
  return must(await supabase
    .from('artisans')
    .select('id, shop_name, slug, status, photo_url, craft_since, created_at, verified_at, town:towns(name), owner:profiles(full_name, email), products(count)')
    .in('status', ['verified', 'suspended'])
    .order('shop_name')) as unknown as AdminArtisan[]
}

export async function setArtisanStatus(id: string, status: 'verified' | 'suspended') {
  must(await supabase.from('artisans').update({ status }).eq('id', id))
}

// --- Users ----------------------------------------------------------------------

export interface AdminUser {
  id: string
  full_name: string
  email: string | null
  role: UserRole
  is_banned: boolean
  created_at: string
}

export async function fetchUsers() {
  return must(await supabase.from('profiles').select('id, full_name, email, role, is_banned, created_at').order('created_at', { ascending: false })) as AdminUser[]
}

export async function setBanned(id: string, banned: boolean) {
  must(await supabase.from('profiles').update({ is_banned: banned }).eq('id', id))
}

// --- Products -------------------------------------------------------------------

export interface AdminProduct {
  id: string
  name: string
  slug: string
  price: number
  stock: number
  is_active: boolean
  is_featured: boolean
  created_at: string
  artisan: { shop_name: string, slug: string, status: ArtisanStatus } | null
  category: { name: string } | null
  images: { url: string, sort_order: number }[]
}

export async function fetchAllProducts() {
  return must(await supabase
    .from('products')
    .select('id, name, slug, price, stock, is_active, is_featured, created_at, artisan:artisans(shop_name, slug, status), category:categories(name), images:product_images(url, sort_order)')
    .order('created_at', { ascending: false })) as unknown as AdminProduct[]
}

export async function setProductFlags(id: string, flags: Partial<Pick<AdminProduct, 'is_active' | 'is_featured'>>) {
  must(await supabase.from('products').update(flags).eq('id', id))
}

// --- Reviews --------------------------------------------------------------------

export interface AdminReview {
  id: string
  rating: number
  comment: string
  is_hidden: boolean
  created_at: string
  product: { name: string, slug: string } | null
  buyer: { full_name: string } | null
}

export async function fetchAllReviews() {
  return must(await supabase
    .from('reviews')
    .select('id, rating, comment, is_hidden, created_at, product:products(name, slug), buyer:profiles(full_name)')
    .order('created_at', { ascending: false })) as unknown as AdminReview[]
}

export async function setReviewHidden(id: string, hidden: boolean) {
  must(await supabase.from('reviews').update({ is_hidden: hidden }).eq('id', id))
}

// --- Orders ---------------------------------------------------------------------

export async function fetchAllOrders() {
  return must(await supabase
    .from('orders')
    .select(`
      id, created_at, total, payment_method, payment_status, maya_checkout_id, ship_recipient, ship_phone, ship_address,
      buyer:profiles(full_name, email),
      shops:order_shops(id, subtotal, shipping_fee, commission, status, shipped_at, delivered_at, artisan:artisans(shop_name, slug), items:order_items(id, product_name, qty, unit_price))
    `)
    .order('created_at', { ascending: false })
    .limit(500)) as unknown as AdminOrder[]
}

export interface AdminOrder {
  id: string
  created_at: string
  total: number
  payment_method: 'maya' | 'cod' | 'mock'
  payment_status: 'unpaid' | 'paid' | 'failed'
  maya_checkout_id: string | null
  ship_recipient: string
  ship_phone: string
  ship_address: string
  buyer: { full_name: string, email: string | null } | null
  shops: {
    id: string
    subtotal: number
    shipping_fee: number
    commission: number
    status: 'pending' | 'shipped' | 'delivered' | 'cancelled'
    shipped_at: string | null
    delivered_at: string | null
    artisan: { shop_name: string, slug: string } | null
    items: { id: string, product_name: string, qty: number, unit_price: number }[]
  }[]
}

// --- Payouts --------------------------------------------------------------------

export interface PayoutBalance {
  artisan_id: string
  shop_name: string
  delivered_orders: number
  online_owed: number
  cod_commission: number
  net: number
}

export async function fetchPayoutBalances() {
  return must(await supabase.rpc('payout_balances')) as PayoutBalance[]
}

export async function settlePayout(artisanId: string) {
  return must(await supabase.rpc('settle_payout', { p_artisan_id: artisanId })) as string
}

export interface PayoutRow {
  id: string
  amount: number
  period: string
  status: 'owed' | 'paid'
  paid_at: string | null
  created_at: string
  artisan: { shop_name: string } | null
}

export async function fetchPayouts() {
  return must(await supabase.from('payouts').select('id, amount, period, status, paid_at, created_at, artisan:artisans(shop_name)').order('created_at', { ascending: false })) as unknown as PayoutRow[]
}

// --- Catalog setup --------------------------------------------------------------

export async function fetchCategoriesWithCounts() {
  return must(await supabase.from('categories').select('id, name, slug, icon, products(count)').order('id')) as unknown as (Category & { products: { count: number }[] })[]
}

export async function saveCategory(input: Pick<Category, 'name' | 'slug'> & { id?: number }) {
  const { id, ...values } = input
  must(id ? await supabase.from('categories').update(values).eq('id', id) : await supabase.from('categories').insert(values))
}

export async function deleteCategory(id: number) {
  must(await supabase.from('categories').delete().eq('id', id))
}

export async function fetchTownsWithCounts() {
  return must(await supabase.from('towns').select('id, name, lat, lng, known_for, artisans(count)').order('name')) as unknown as (Town & { artisans: { count: number }[] })[]
}

export async function saveTown(input: Omit<Town, 'id'> & { id?: number }) {
  const { id, ...values } = input
  must(id ? await supabase.from('towns').update(values).eq('id', id) : await supabase.from('towns').insert(values))
}

export async function deleteTown(id: number) {
  must(await supabase.from('towns').delete().eq('id', id))
}

// --- Homepage -------------------------------------------------------------------

// Monday of the current week, as YYYY-MM-DD in Philippine time.
export function weekStart(date = new Date()) {
  const manila = new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Manila' }))
  const day = (manila.getDay() + 6) % 7
  manila.setDate(manila.getDate() - day)
  return `${manila.getFullYear()}-${String(manila.getMonth() + 1).padStart(2, '0')}-${String(manila.getDate()).padStart(2, '0')}`
}

export async function fetchFeaturedHistory() {
  return must(await supabase.from('featured_artisans').select('id, week_start, artisan:artisans(id, shop_name, slug, photo_url)').order('week_start', { ascending: false }).limit(12)) as unknown as {
    id: string
    week_start: string
    artisan: { id: string, shop_name: string, slug: string, photo_url: string | null } | null
  }[]
}

export async function setFeaturedArtisan(artisanId: string, week = weekStart()) {
  must(await supabase.from('featured_artisans').upsert({ artisan_id: artisanId, week_start: week }, { onConflict: 'week_start' }))
}

export interface Banner {
  id: string
  image_url: string
  link: string | null
  sort_order: number
  is_active: boolean
}

export async function fetchBanners() {
  return must(await supabase.from('banners').select('*').order('sort_order')) as Banner[]
}

export async function saveBanner(input: Omit<Banner, 'id'> & { id?: string }) {
  const { id, ...values } = input
  must(id ? await supabase.from('banners').update(values).eq('id', id) : await supabase.from('banners').insert(values))
}

export async function deleteBanner(id: string) {
  must(await supabase.from('banners').delete().eq('id', id))
}

// --- Settings -------------------------------------------------------------------

export async function fetchSettings() {
  const rows = must(await supabase.from('settings').select('key, value')) as { key: string, value: unknown }[]
  return Object.fromEntries(rows.map(r => [r.key, r.value])) as Record<string, unknown>
}

export async function saveSetting(key: string, value: unknown) {
  must(await supabase.from('settings').upsert({ key, value }))
}

// --- Activity log ---------------------------------------------------------------

export interface ActivityRow {
  id: number
  action: string
  target_table: string
  target_id: string
  details: Record<string, unknown> | null
  created_at: string
  actor: { full_name: string } | null
}

export async function fetchActivity(page = 0, pageSize = 50) {
  const from = page * pageSize
  const { data, count, error } = await supabase
    .from('activity_log')
    .select('id, action, target_table, target_id, details, created_at, actor:profiles(full_name)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + pageSize - 1)
  if (error) throw error
  return { rows: (data ?? []) as unknown as ActivityRow[], total: count ?? 0 }
}

export const actionLabels: Record<string, string> = {
  approve_artisan: 'Approved an artisan application',
  reject_artisan: 'Rejected an artisan application',
  suspend_artisan: 'Suspended a shop',
  reactivate_artisan: 'Reactivated a shop',
  ban_user: 'Banned a user',
  unban_user: 'Unbanned a user',
  hide_product: 'Hid a product',
  unhide_product: 'Unhid a product',
  feature_product: 'Featured a product',
  unfeature_product: 'Unfeatured a product',
  hide_review: 'Hid a review',
  unhide_review: 'Unhid a review',
  update_setting: 'Changed a setting',
  feature_artisan: 'Set the featured artisan',
  settle_payout: 'Recorded a payout',
}
