<script setup lang="ts">
import type { CatalogProduct } from '@/lib/catalog'
import type { Review } from '@/types/database'
import { ChevronRightIcon, MapPinIcon, PackageIcon, ShoppingBagIcon, StarIcon, TruckIcon } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import EmptyState from '@/components/catalog/EmptyState.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import QtyStepper from '@/components/QtyStepper.vue'
import WishlistButton from '@/components/WishlistButton.vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import { Button } from '@/components/ui/button'
import { fetchProduct, fetchProducts, fetchReviews } from '@/lib/catalog'
import { peso, yearsInCraft } from '@/lib/format'
import { categoryImages, images } from '@/lib/images'
import { cn } from '@/lib/utils'
import { useCartStore } from '@/stores/cart'

const route = useRoute()
const router = useRouter()
const cart = useCartStore()

const inCart = computed(() => cart.lines.find(l => l.productId === product.value?.id)?.qty ?? 0)

function addToCart() {
  if (!product.value) return
  const room = product.value.stock - inCart.value
  if (room <= 0) {
    toast.info('You already have all the available pieces in your cart.')
    return
  }
  cart.add(product.value, Math.min(qty.value, room))
  toast.success(`Added ${product.value.name} to your cart`, { action: { label: 'View cart', onClick: () => router.push('/cart') } })
}

const product = ref<CatalogProduct | null>(null)
const reviews = ref<Pick<Review, 'id' | 'rating' | 'comment' | 'created_at'>[]>([])
const more = ref<CatalogProduct[]>([])
const loading = ref(true)
const activeImage = ref(0)
const qty = ref(1)

const gallery = computed(() => {
  if (!product.value) return []
  const urls = [...product.value.images].sort((a, b) => a.sort_order - b.sort_order).map(i => i.url)
  return urls.length ? urls : [categoryImages[product.value.category?.slug ?? ''] ?? images.wovenTexture]
})

const rating = computed(() => {
  if (!reviews.value.length) return null
  return reviews.value.reduce((s, r) => s + r.rating, 0) / reviews.value.length
})

async function load(slug: string) {
  loading.value = true
  activeImage.value = 0
  qty.value = 1
  try {
    product.value = await fetchProduct(slug)
    if (product.value) {
      document.title = `${product.value.name} · CraftCebu`
      const [r, m] = await Promise.all([
        fetchReviews(product.value.id),
        fetchProducts({ artisanId: product.value.artisan_id }, 0, 5),
      ])
      reviews.value = r
      more.value = m.products.filter(p => p.id !== product.value?.id).slice(0, 4)
    }
  }
  finally {
    loading.value = false
  }
}

watch(() => route.params.slug, slug => typeof slug === 'string' && load(slug), { immediate: true })
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 pt-8 pb-28 md:pb-8">
    <div v-if="loading" class="grid gap-10 md:grid-cols-2">
      <div class="aspect-[4/5] animate-pulse rounded-2xl bg-muted" />
      <div class="grid content-start gap-4">
        <div class="h-10 w-3/4 animate-pulse rounded bg-muted" />
        <div class="h-6 w-1/3 animate-pulse rounded bg-muted" />
        <div class="h-24 animate-pulse rounded bg-muted" />
      </div>
    </div>

    <EmptyState v-else-if="!product" title="Wala diri · Not found" body="This piece may have sold out for good or been taken down by its maker.">
      <Button as-child variant="outline"><RouterLink to="/shop">Back to the crafts</RouterLink></Button>
    </EmptyState>

    <template v-else>
      <nav class="flex items-center gap-1 text-sm text-muted-foreground" aria-label="Breadcrumb">
        <RouterLink to="/shop" class="hover:text-foreground">Crafts</RouterLink>
        <template v-if="product.category">
          <ChevronRightIcon class="size-3.5" />
          <RouterLink :to="{ path: '/shop', query: { category: product.category.slug } }" class="hover:text-foreground">{{ product.category.name }}</RouterLink>
        </template>
        <ChevronRightIcon class="size-3.5" />
        <span class="truncate text-foreground">{{ product.name }}</span>
      </nav>

      <div class="mt-6 grid gap-10 md:grid-cols-2 lg:gap-16">
        <!-- Gallery -->
        <div>
          <div class="relative overflow-hidden rounded-2xl bg-muted">
            <img :src="gallery[activeImage]" :alt="product.name" class="aspect-[4/5] w-full object-cover">
            <div class="hablon-v absolute inset-y-0 left-0 w-2.5" aria-hidden="true" />
          </div>
          <div v-if="gallery.length > 1" class="mt-3 flex gap-3">
            <button
              v-for="(url, i) in gallery"
              :key="url"
              :aria-label="`Show photo ${i + 1}`"
              :aria-current="activeImage === i"
              :class="cn('size-20 overflow-hidden rounded-lg border-2 transition-colors', activeImage === i ? 'border-primary' : 'border-transparent opacity-70 hover:opacity-100')"
              @click="activeImage = i"
            >
              <img :src="url" alt="" class="size-full object-cover">
            </button>
          </div>
        </div>

        <!-- Details -->
        <div>
          <p v-if="product.artisan.town" class="caps flex items-center gap-1.5 text-primary">
            <MapPinIcon class="size-3.5" /> Gikan sa {{ product.artisan.town.name }}
          </p>
          <h1 class="mt-3 font-display text-4xl leading-tight font-medium sm:text-5xl">{{ product.name }}</h1>
          <div class="mt-3 flex flex-wrap items-center gap-3 text-sm">
            <RouterLink :to="`/artisans/${product.artisan.slug}`" class="font-medium underline-offset-4 hover:underline">{{ product.artisan.shop_name }}</RouterLink>
            <VerifiedBadge compact />
            <span v-if="rating" class="flex items-center gap-1 text-muted-foreground">
              <StarIcon class="size-4 fill-mango text-mango" /> {{ rating.toFixed(1) }} ({{ reviews.length }})
            </span>
          </div>

          <p class="mt-6 font-display text-4xl">{{ peso(product.price) }}</p>
          <p v-if="inCart" class="mt-1 text-sm text-muted-foreground">{{ inCart }} in your cart</p>
          <p :class="cn('mt-1 text-sm', product.stock === 0 ? 'text-destructive' : product.stock <= 5 ? 'text-primary' : 'text-muted-foreground')">
            {{ product.stock === 0 ? 'Sold out' : product.stock <= 5 ? `Only ${product.stock} left` : `${product.stock} in stock` }}
          </p>

          <!-- On phones this bar is pinned above the home indicator, like an app's buy bar -->
          <div class="pb-safe-4 fixed inset-x-0 bottom-0 z-30 flex items-center gap-2 border-t bg-background/95 px-4 pt-3 backdrop-blur md:static md:mt-8 md:gap-3 md:border-0 md:bg-transparent md:p-0 md:backdrop-blur-none">
            <QtyStepper v-model="qty" :max="Math.max(1, product.stock - inCart)" />
            <Button size="lg" class="min-w-0 flex-1 px-4" :disabled="product.stock === 0" @click="addToCart">
              <ShoppingBagIcon /> {{ product.stock === 0 ? 'Sold out' : 'Add to cart' }}
            </Button>
            <WishlistButton :product-id="product.id" :product-name="product.name" variant="page" />
          </div>

          <ul class="mt-8 grid gap-3 rounded-xl bg-secondary p-5 text-sm">
            <li class="flex gap-3"><TruckIcon class="size-5 shrink-0 text-primary" /> Shipped by {{ product.artisan.shop_name }} with a flat shipping fee per shop.</li>
            <li class="flex gap-3"><PackageIcon class="size-5 shrink-0 text-primary" /> Pay with Maya or cash on delivery.</li>
          </ul>

          <section class="mt-10">
            <h2 class="font-display text-2xl font-medium">About this piece</h2>
            <p class="mt-3 leading-relaxed whitespace-pre-line text-muted-foreground">{{ product.description || 'The maker hasn\'t added a description yet.' }}</p>
            <dl v-if="product.materials || product.category" class="mt-6 grid grid-cols-2 gap-4 border-t pt-6 text-sm">
              <div v-if="product.materials">
                <dt class="text-muted-foreground">Materials</dt>
                <dd class="mt-1 font-medium">{{ product.materials }}</dd>
              </div>
              <div v-if="product.category">
                <dt class="text-muted-foreground">Craft</dt>
                <dd class="mt-1 font-medium">{{ product.category.name }}</dd>
              </div>
            </dl>
          </section>
        </div>
      </div>

      <!-- Maker card -->
      <section class="mt-16 grid items-center gap-6 rounded-2xl border bg-card p-6 sm:grid-cols-[auto_1fr_auto] sm:p-8">
        <img v-if="product.artisan.photo_url" :src="product.artisan.photo_url" :alt="product.artisan.shop_name" class="size-20 rounded-full object-cover">
        <div v-else class="grid size-20 place-items-center rounded-full bg-primary font-display text-3xl text-primary-foreground">{{ product.artisan.shop_name[0] }}</div>
        <div>
          <p class="caps text-muted-foreground">Ang naghimo · The maker</p>
          <h2 class="mt-1 font-display text-2xl font-medium">{{ product.artisan.shop_name }}</h2>
          <p class="mt-1 text-sm text-muted-foreground">
            <span v-if="product.artisan.town">{{ product.artisan.town.name }}, Cebu</span>
            <span v-if="yearsInCraft(product.artisan.craft_since)"> · {{ yearsInCraft(product.artisan.craft_since) }} years in the craft</span>
          </p>
          <p class="mt-3 line-clamp-2 max-w-2xl text-sm leading-relaxed">{{ product.artisan.story }}</p>
        </div>
        <Button as-child variant="outline"><RouterLink :to="`/artisans/${product.artisan.slug}`">Visit shop</RouterLink></Button>
      </section>

      <!-- Reviews -->
      <section class="mt-16">
        <h2 class="font-display text-3xl font-medium">Reviews</h2>
        <p v-if="!reviews.length" class="mt-3 text-sm text-muted-foreground">No reviews yet. Buyers can review a piece once it's delivered.</p>
        <ul v-else class="mt-6 grid gap-4 md:grid-cols-2">
          <li v-for="r in reviews" :key="r.id" class="rounded-xl border bg-card p-5">
            <div class="flex items-center gap-0.5" :aria-label="`${r.rating} out of 5 stars`">
              <StarIcon v-for="n in 5" :key="n" :class="cn('size-4', n <= r.rating ? 'fill-mango text-mango' : 'text-border')" />
            </div>
            <p class="mt-3 text-sm leading-relaxed">{{ r.comment || 'No comment.' }}</p>
            <p class="mt-3 text-xs text-muted-foreground">Verified buyer · {{ new Date(r.created_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) }}</p>
          </li>
        </ul>
      </section>

      <!-- More from this maker -->
      <section v-if="more.length" class="mt-16">
        <h2 class="font-display text-3xl font-medium">More from {{ product.artisan.shop_name }}</h2>
        <div class="mt-6 grid grid-cols-2 gap-x-5 gap-y-10 md:grid-cols-4">
          <ProductCard v-for="p in more" :key="p.id" :product="p" />
        </div>
      </section>
    </template>
  </div>
</template>
