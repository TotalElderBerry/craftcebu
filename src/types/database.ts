export type UserRole = 'buyer' | 'artisan' | 'owner'

export interface Profile {
  id: string
  full_name: string
  role: UserRole
  avatar_url: string | null
  is_banned: boolean
  email?: string | null
  created_at: string
}

export interface Town {
  id: number
  name: string
  lat: number
  lng: number
  known_for: string
}

export interface Category {
  id: number
  name: string
  slug: string
  icon: string | null
}

export type ArtisanStatus = 'pending' | 'verified' | 'rejected' | 'suspended'

export interface Artisan {
  id: string
  profile_id: string
  shop_name: string
  slug: string
  story: string
  town_id: number | null
  craft_since: number | null
  photo_url: string | null
  status: ArtisanStatus
  sample_photos: string[]
  reject_reason: string | null
  verified_at: string | null
  created_at: string
}

export interface Product {
  id: string
  artisan_id: string
  category_id: number | null
  name: string
  slug: string
  description: string
  materials: string
  price: number
  stock: number
  is_active: boolean
  is_featured: boolean
  created_at: string
}

export interface CartItem {
  profile_id: string
  product_id: string
  qty: number
  created_at: string
  updated_at: string
}

export interface ProductImage {
  id: string
  product_id: string
  url: string
  sort_order: number
}

export interface Review {
  id: string
  product_id: string
  rating: number
  comment: string
  created_at: string
}

export type PaymentMethod = 'maya' | 'cod' | 'mock'
export type PaymentStatus = 'unpaid' | 'paid' | 'failed'
export type ShopOrderStatus = 'pending' | 'shipped' | 'delivered' | 'cancelled'

export interface Address {
  id: string
  profile_id: string
  recipient: string
  phone: string
  street: string
  barangay: string
  city: string
  province: string
  is_default: boolean
}
