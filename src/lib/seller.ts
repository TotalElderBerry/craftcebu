import type { Artisan, ArtisanStatus, Product, ProductImage } from '@/types/database'
import { uniqueSlug } from '@/lib/slug'
import { supabase } from '@/lib/supabase'

export type MyArtisan = Artisan

export interface ApplicationInput {
  shop_name: string
  story: string
  town_id: number | null
  craft_since: number | null
  photo_url: string | null
  sample_photos: string[]
}

export async function fetchMyArtisan(userId: string) {
  const { data, error } = await supabase.from('artisans').select('*').eq('profile_id', userId).maybeSingle()
  if (error) throw error
  return data as MyArtisan | null
}

export async function submitApplication(userId: string, input: ApplicationInput) {
  const { data, error } = await supabase
    .from('artisans')
    .insert({ ...input, profile_id: userId, slug: uniqueSlug(input.shop_name) })
    .select('*')
    .single()
  if (error) throw error
  return data as MyArtisan
}

export async function updateShop(artisanId: string, input: Partial<ApplicationInput>) {
  const { error } = await supabase.from('artisans').update(input).eq('id', artisanId)
  if (error) throw error
}

export async function resubmitApplication() {
  const { error } = await supabase.rpc('resubmit_artisan_application')
  if (error) throw error
}

// --- Products --------------------------------------------------------------

export type SellerProduct = Product & { images: Pick<ProductImage, 'id' | 'url' | 'sort_order'>[], category: { name: string } | null }

export async function fetchMyProducts(artisanId: string) {
  const { data, error } = await supabase
    .from('products')
    .select('*, images:product_images(id, url, sort_order), category:categories(name)')
    .eq('artisan_id', artisanId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as SellerProduct[]
}

export async function fetchMyProduct(id: string) {
  const { data, error } = await supabase
    .from('products')
    .select('*, images:product_images(id, url, sort_order), category:categories(name)')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return data as SellerProduct | null
}

export interface ProductInput {
  name: string
  category_id: number | null
  description: string
  materials: string
  price: number
  stock: number
  is_active: boolean
}

// Saves the product, then replaces its image list with `imageUrls` in order
// (the first one is the cover).
export async function saveProduct(artisanId: string, input: ProductInput, imageUrls: string[], id?: string) {
  let productId = id
  if (productId) {
    const { error } = await supabase.from('products').update(input).eq('id', productId)
    if (error) throw error
  }
  else {
    const { data, error } = await supabase
      .from('products')
      .insert({ ...input, artisan_id: artisanId, slug: uniqueSlug(input.name) })
      .select('id')
      .single()
    if (error) throw error
    productId = data.id as string
  }

  const { error: delError } = await supabase.from('product_images').delete().eq('product_id', productId)
  if (delError) throw delError
  if (imageUrls.length) {
    const { error: imgError } = await supabase
      .from('product_images')
      .insert(imageUrls.map((url, i) => ({ product_id: productId, url, sort_order: i })))
    if (imgError) throw imgError
  }
  return productId
}

export async function setProductActive(id: string, isActive: boolean) {
  const { error } = await supabase.from('products').update({ is_active: isActive }).eq('id', id)
  if (error) throw error
}

export async function deleteProduct(id: string) {
  const { error } = await supabase.from('products').delete().eq('id', id)
  if (error) throw error
}

// --- Owner: applications ----------------------------------------------------

export type Application = MyArtisan & {
  town: { name: string } | null
  owner: { full_name: string } | null
}

export async function fetchApplications(status: ArtisanStatus) {
  const { data, error } = await supabase
    .from('artisans')
    .select('*, town:towns(name), owner:profiles(full_name)')
    .eq('status', status)
    .order('created_at', { ascending: status === 'pending' })
  if (error) throw error
  return (data ?? []) as Application[]
}

export async function reviewApplication(artisanId: string, approve: boolean, reason?: string) {
  const { error } = await supabase.rpc('review_artisan_application', {
    p_artisan_id: artisanId,
    p_approve: approve,
    p_reason: reason ?? null,
  })
  if (error) throw error
}
