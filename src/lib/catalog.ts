import type { Artisan, Category, Product, ProductImage, Town } from '@/types/database'
import { supabase } from '@/lib/supabase'

// What a product card needs: the product plus its maker, town, category and photos.
export type CatalogProduct = Product & {
  artisan: Pick<Artisan, 'id' | 'shop_name' | 'slug' | 'status' | 'town_id' | 'story' | 'craft_since' | 'photo_url'> & { town: Pick<Town, 'id' | 'name'> | null }
  category: Pick<Category, 'name' | 'slug'> | null
  images: Pick<ProductImage, 'url' | 'sort_order'>[]
  // Filled in by withRatings(); absent when a product has no visible reviews.
  rating?: number
  review_count?: number
}

// Average star rating of visible reviews, added to each product in one query.
async function withRatings(products: CatalogProduct[]) {
  if (!products.length) return products
  const { data } = await supabase.from('reviews').select('product_id, rating').in('product_id', products.map(p => p.id)).eq('is_hidden', false)
  const totals = new Map<string, { sum: number, n: number }>()
  for (const r of data ?? []) {
    const t = totals.get(r.product_id) ?? { sum: 0, n: 0 }
    t.sum += r.rating
    t.n += 1
    totals.set(r.product_id, t)
  }
  return products.map((p) => {
    const t = totals.get(p.id)
    return t ? { ...p, rating: t.sum / t.n, review_count: t.n } : p
  })
}

// Inner joins keep only products whose artisan is verified (and, when filtering,
// whose category matches); RLS enforces the same rule for the public.
export const productSelect = `
  *,
  artisan:artisans!inner(id, shop_name, slug, status, town_id, story, craft_since, photo_url, town:towns(id, name)),
  category:categories(name, slug),
  images:product_images(url, sort_order)
`
const productSelectByCategory = productSelect.replace('category:categories(', 'category:categories!inner(')

export type SortKey = 'newest' | 'price-asc' | 'price-desc'

export interface CatalogFilters {
  q?: string
  category?: string
  townId?: number
  minPrice?: number
  maxPrice?: number
  artisanId?: string
  sort?: SortKey
}

// PostgREST's or() filter uses commas and parentheses as syntax.
const cleanSearch = (q: string) => q.replace(/[,()*%\\]/g, ' ').trim()

export async function fetchProducts(filters: CatalogFilters, page = 0, pageSize = 12) {
  let query = supabase
    .from('products')
    .select(filters.category ? productSelectByCategory : productSelect, { count: 'exact' })
    .eq('is_active', true)
    .eq('artisan.status', 'verified')

  const q = filters.q ? cleanSearch(filters.q) : ''
  if (q) query = query.or(`name.ilike.%${q}%,description.ilike.%${q}%,materials.ilike.%${q}%`)
  if (filters.category) query = query.eq('category.slug', filters.category)
  if (filters.townId) query = query.eq('artisan.town_id', filters.townId)
  if (filters.artisanId) query = query.eq('artisan_id', filters.artisanId)
  if (filters.minPrice != null) query = query.gte('price', filters.minPrice)
  if (filters.maxPrice != null) query = query.lte('price', filters.maxPrice)

  if (filters.sort === 'price-asc') query = query.order('price', { ascending: true })
  else if (filters.sort === 'price-desc') query = query.order('price', { ascending: false })
  else query = query.order('created_at', { ascending: false })

  const from = page * pageSize
  const { data, count, error } = await query.range(from, from + pageSize - 1)
  if (error) throw error
  return { products: await withRatings((data ?? []) as unknown as CatalogProduct[]), total: count ?? 0 }
}

export async function fetchProduct(slug: string) {
  const { data, error } = await supabase
    .from('products')
    .select(productSelect)
    .eq('slug', slug)
    .eq('is_active', true)
    .eq('artisan.status', 'verified')
    .maybeSingle()
  if (error) throw error
  return data as unknown as CatalogProduct | null
}

export async function fetchReviews(productId: string) {
  const { data, error } = await supabase
    .from('reviews')
    .select('id, rating, comment, created_at')
    .eq('product_id', productId)
    .eq('is_hidden', false)
    .order('created_at', { ascending: false })
  if (error) throw error
  return data ?? []
}

export type ShopArtisan = Pick<Artisan, 'id' | 'shop_name' | 'slug' | 'story' | 'craft_since' | 'photo_url' | 'created_at'> & {
  town: Pick<Town, 'id' | 'name' | 'known_for'> | null
}

export async function fetchArtisan(slug: string) {
  const { data, error } = await supabase
    .from('artisans')
    .select('id, shop_name, slug, story, craft_since, photo_url, created_at, town:towns(id, name, known_for)')
    .eq('slug', slug)
    .eq('status', 'verified')
    .maybeSingle()
  if (error) throw error
  return data as unknown as ShopArtisan | null
}

export async function fetchArtisans() {
  const { data, error } = await supabase
    .from('artisans')
    .select('id, shop_name, slug, story, craft_since, photo_url, created_at, town:towns(id, name, known_for)')
    .eq('status', 'verified')
    .order('shop_name')
  if (error) throw error
  return (data ?? []) as unknown as ShopArtisan[]
}

export async function fetchFacets() {
  const [towns, categories] = await Promise.all([
    supabase.from('towns').select('id, name').order('name'),
    supabase.from('categories').select('id, name, slug').order('id'),
  ])
  return {
    towns: (towns.data ?? []) as Pick<Town, 'id' | 'name'>[],
    categories: (categories.data ?? []) as Pick<Category, 'id' | 'name' | 'slug'>[],
  }
}

export const coverImage = (p: Pick<CatalogProduct, 'images'>) =>
  [...p.images].sort((a, b) => a.sort_order - b.sort_order)[0]?.url ?? null

// Current price and stock for the products in a cart.
export async function fetchProductsByIds(ids: string[]) {
  if (!ids.length) return []
  const { data, error } = await supabase
    .from('products')
    .select(productSelect)
    .in('id', ids)
    .eq('is_active', true)
    .eq('artisan.status', 'verified')
  if (error) throw error
  return (data ?? []) as unknown as CatalogProduct[]
}

export async function fetchShippingFee() {
  const { data } = await supabase.from('settings').select('value').eq('key', 'shipping_fee_per_shop').maybeSingle()
  return Number(data?.value ?? 0)
}
