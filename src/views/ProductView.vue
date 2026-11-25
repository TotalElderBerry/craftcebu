<script setup lang="ts">
import type { CatalogProduct } from '@/lib/catalog'
import type { Review } from '@/types/database'
import { BanknoteIcon, ChevronDownIcon, ChevronRightIcon, HandIcon, MapPinIcon, Share2Icon, ShoppingBagIcon, StarIcon, TruckIcon } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import EmptyState from '@/components/catalog/EmptyState.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import QtyStepper from '@/components/QtyStepper.vue'
import { Button } from '@/components/ui/button'
import WishlistButton from '@/components/WishlistButton.vue'
import { fetchProduct, fetchProducts, fetchReviews } from '@/lib/catalog'
import { peso, yearsInCraft } from '@/lib/format'
import { categoryImages, images } from '@/lib/images'
import { cn } from '@/lib/utils'
import { useCartStore } from '@/stores/cart'

const route = useRoute()
const router = useRouter()
const cart = useCartStore()

const product = ref<CatalogProduct | null>(null)
const reviews = ref<Pick<Review, 'id' | 'rating' | 'comment' | 'created_at'>[]>([])
const fromMaker = ref<CatalogProduct[]>([])
const related = ref<CatalogProduct[]>([])
const loading = ref(true)
const activeImage = ref(0)
const qty = ref(1)
const scroller = ref<HTMLElement | null>(null)

const inCart = computed(() => cart.lines.find(l => l.productId === product.value?.id)?.qty ?? 0)
const room = computed(() => (product.value ? product.value.stock - inCart.value : 0))

const gallery = computed(() => {
  if (!product.value) return []
  const urls = [...product.value.images].sort((a, b) => a.sort_order - b.sort_order).map(i => i.url)
  return urls.length ? urls : [categoryImages[product.value.category?.slug ?? ''] ?? images.wovenTexture]
})

const rating = computed(() => (reviews.value.length ? reviews.value.reduce((s, r) => s + r.rating, 0) / reviews.value.length : null))
// How many reviews gave each star count, 5 down to 1.
const breakdown = computed(() => [5, 4, 3, 2, 1].map(stars => ({ stars, count: reviews.value.filter(r => r.rating === stars).length })))

const stockLabel = computed(() => {
  const s = product.value?.stock ?? 0
  if (s === 0) return { text: 'Sold out', tone: 'bg-secondary text-muted-foreground' }
  if (s <= 5) return { text: `Only ${s} left`, tone: 'bg-primary/10 text-primary' }
  return { text: 'In stock', tone: 'bg-[oklch(0.93_0.06_150)] text-[oklch(0.4_0.1_150)]' }
})

async function addToCart() {
  const piece = product.value
  if (!piece) return
  if (room.value <= 0) {
    toast.info('You already have all the available pieces in your cart.')
    return
  }
  if (!await cart.add(piece, Math.min(qty.value, room.value))) return
  toast.success(`Added ${piece.name} to your cart`, { action: { label: 'View cart', onClick: () => router.push('/cart') } })
}

async function share() {
  if (!product.value) return
  const data = { title: product.value.name, text: `${product.value.name} by ${product.value.artisan.shop_name} on CraftCebu`, url: window.location.href }
  try {
    if (navigator.share) await navigator.share(data)
    else {
      await navigator.clipboard.writeText(data.url)
      toast.success('Link copied.')
    }
  }
  catch {
    // The share sheet was dismissed; nothing to do.
  }
}

// Phones swipe through photos; keep the dots in step with the scroll position.
function onScroll() {
  const el = scroller.value
  if (el) activeImage.value = Math.round(el.scrollLeft / el.clientWidth)
}
function showImage(i: number) {
  activeImage.value = i
  scroller.value?.scrollTo({ left: i * scroller.value.clientWidth, behavior: 'smooth' })
}

async function load(slug: string) {
  loading.value = true
  activeImage.value = 0
  qty.value = 1
  try {
    product.value = await fetchProduct(slug)
    if (product.value) {
      document.title = `${product.value.name} · CraftCebu`
      const p = product.value
      const [r, m, c] = await Promise.all([
        fetchReviews(p.id),
        fetchProducts({ artisanId: p.artisan_id }, 0, 9),
        p.category ? fetchProducts({ category: p.category.slug }, 0, 12) : Promise.resolve({ products: [] as CatalogProduct[] }),
      ])
      reviews.value = r
      fromMaker.value = m.products.filter(x => x.id !== p.id).slice(0, 8)
      related.value = c.products.filter(x => x.artisan_id !== p.artisan_id).slice(0, 8)
    }
  }
  finally {
    loading.value = false
  }
}

watch(() => route.params.slug, slug => typeof slug === 'string' && load(slug), { immediate: true })
</script>

<template>
  <div class="mx-auto max-w-6xl pb-32 md:px-4 md:pt-8 md:pb-16">
    <div v-if="loading" class="grid gap-8 md:grid-cols-2">
      <div class="aspect-[4/5] animate-pulse bg-muted md:rounded-3xl" />
      <div class="grid content-start gap-4 px-4 md:px-0">
        <div class="h-10 w-3/4 animate-pulse rounded bg-muted" />
        <div class="h-6 w-1/3 animate-pulse rounded bg-muted" />
        <div class="h-24 animate-pulse rounded bg-muted" />
      </div>
    </div>

    <div v-else-if="!product" class="px-4 pt-8">
      <EmptyState title="Wala diri · Not found" body="This piece may have sold out for good or been taken down by its maker.">
        <Button as-child variant="outline"><RouterLink to="/shop">Back to the crafts</RouterLink></Button>
      </EmptyState>
    </div>

    <template v-else>
      <nav class="mb-6 hidden items-center gap-1 text-sm text-muted-foreground md:flex" aria-label="Breadcrumb">
        <RouterLink to="/shop" class="hover:text-foreground">Crafts</RouterLink>
        <template v-if="product.category">
          <ChevronRightIcon class="size-3.5" />
          <RouterLink :to="{ path: '/shop', query: { category: product.category.slug } }" class="hover:text-foreground">{{ product.category.name }}</RouterLink>
        </template>
        <ChevronRightIcon class="size-3.5" />
        <span class="truncate text-foreground">{{ product.name }}</span>
      </nav>

      <div class="grid md:grid-cols-[1.1fr_1fr] md:gap-12 lg:gap-16">
        <!-- Gallery: swipeable and full-bleed on phones, thumbnails beside it on desktop -->
        <div class="md:flex md:gap-4 md:self-start lg:sticky lg:top-24">
          <div v-if="gallery.length > 1" class="hidden w-20 shrink-0 flex-col gap-3 md:flex">
            <button
              v-for="(url, i) in gallery"
              :key="url"
              :aria-label="`Show photo ${i + 1}`"
              :aria-current="activeImage === i"
              :class="cn('aspect-square overflow-hidden rounded-xl border-2 transition', activeImage === i ? 'border-primary' : 'border-transparent opacity-60 hover:opacity-100')"
              @click="showImage(i)"
            >
              <img :src="url" alt="" class="size-full object-cover">
            </button>
          </div>
          <div class="relative min-w-0 flex-1">
            <div ref="scroller" class="flex snap-x snap-mandatory overflow-x-auto [scrollbar-width:none] md:rounded-3xl" @scroll.passive="onScroll">
              <img
                v-for="(url, i) in gallery"
                :key="url"
                :src="url"
                :alt="i === 0 ? product.name : `${product.name}, photo ${i + 1}`"
                class="aspect-[4/5] w-full shrink-0 snap-center object-cover"
              >
            </div>
            <div class="hablon-v pointer-events-none absolute inset-y-0 left-0 w-2 md:rounded-l-3xl" aria-hidden="true" />
            <div class="absolute top-3 right-3 flex flex-col gap-2">
              <WishlistButton :product-id="product.id" :product-name="product.name" />
              <button type="button" class="grid size-10 place-items-center rounded-full bg-background/90 shadow-sm hover:bg-background" aria-label="Share this piece" @click="share">
                <Share2Icon class="size-4" />
              </button>
            </div>
            <div v-if="gallery.length > 1" class="absolute inset-x-0 bottom-9 flex justify-center gap-1.5 md:bottom-4">
              <button
                v-for="(url, i) in gallery"
                :key="url"
                :aria-label="`Show photo ${i + 1}`"
                class="grid h-6 place-items-center px-0.5"
                @click="showImage(i)"
              >
                <span :class="cn('block h-1.5 rounded-full transition-all', activeImage === i ? 'w-6 bg-white' : 'w-1.5 bg-white/60')" />
              </button>
            </div>
          </div>
        </div>

        <!-- Details: a sheet over the photo on phones -->
        <div class="relative -mt-6 rounded-t-3xl bg-background px-4 pt-6 md:mt-0 md:rounded-none md:px-0 md:pt-0">
          <div class="flex flex-wrap items-center gap-2 text-xs font-medium">
            <RouterLink v-if="product.artisan.town" :to="{ path: '/origins', query: { town: product.artisan.town.name } }" class="flex h-8 items-center gap-1 rounded-full bg-secondary px-3 hover:bg-accent">
              <MapPinIcon class="size-3.5 text-primary" /> Gikan sa {{ product.artisan.town.name }}
            </RouterLink>
            <RouterLink v-if="product.category" :to="{ path: '/shop', query: { category: product.category.slug } }" class="flex h-8 items-center rounded-full bg-secondary px-3 hover:bg-accent">{{ product.category.name }}</RouterLink>
          </div>

          <h1 class="mt-4 font-display text-3xl leading-tight font-medium sm:text-4xl lg:text-5xl">{{ product.name }}</h1>

          <a href="#reviews" class="mt-2 inline-flex items-center gap-1.5 py-1 text-sm text-muted-foreground hover:text-foreground">
            <template v-if="rating">
              <span class="flex" aria-hidden="true">
                <StarIcon v-for="n in 5" :key="n" :class="cn('size-4', n <= Math.round(rating) ? 'fill-mango text-mango' : 'text-border')" />
              </span>
              <span class="font-medium text-foreground">{{ rating.toFixed(1) }}</span> · {{ reviews.length }} {{ reviews.length === 1 ? 'review' : 'reviews' }}
            </template>
            <template v-else>No reviews yet</template>
          </a>

          <div class="mt-5 flex items-center gap-3">
            <p class="font-display text-4xl">{{ peso(product.price) }}</p>
            <span :class="cn('rounded-full px-3 py-1 text-xs font-semibold', stockLabel.tone)">{{ stockLabel.text }}</span>
          </div>
          <p v-if="inCart" class="mt-1 text-sm text-muted-foreground">{{ inCart }} already in your cart</p>

          <!-- Desktop buying controls (phones use the bottom bar) -->
          <div class="mt-6 hidden items-center gap-3 md:flex">
            <QtyStepper v-model="qty" :max="Math.max(1, room)" />
            <Button size="lg" class="flex-1" :disabled="product.stock === 0" @click="addToCart">
              <ShoppingBagIcon /> {{ product.stock === 0 ? 'Sold out' : 'Add to cart' }}
            </Button>
          </div>

          <!-- Phones pick the quantity here, then tap the bottom bar -->
          <div v-if="product.stock > 0" class="mt-5 flex items-center justify-between md:hidden">
            <span class="text-sm font-medium">Quantity</span>
            <QtyStepper v-model="qty" :max="Math.max(1, room)" size="sm" />
          </div>

          <!-- The maker, before the details -->
          <RouterLink :to="`/artisans/${product.artisan.slug}`" class="mt-6 flex items-center gap-3 rounded-2xl border bg-card p-4 transition-colors hover:border-primary/40">
            <img v-if="product.artisan.photo_url" :src="product.artisan.photo_url" :alt="product.artisan.shop_name" class="size-14 shrink-0 rounded-full object-cover">
            <span v-else class="grid size-14 shrink-0 place-items-center rounded-full bg-primary font-display text-2xl text-primary-foreground">{{ product.artisan.shop_name[0] }}</span>
            <span class="min-w-0 flex-1">
              <span class="caps block text-muted-foreground">Hinimo ni · Made by</span>
              <span class="mt-0.5 flex items-center gap-1.5 font-display text-lg font-medium">{{ product.artisan.shop_name }} <VerifiedBadge compact /></span>
              <span class="block truncate text-xs text-muted-foreground">
                {{ product.artisan.town?.name ?? 'Cebu' }}<template v-if="yearsInCraft(product.artisan.craft_since)"> · {{ yearsInCraft(product.artisan.craft_since) }} years in the craft</template>
              </span>
            </span>
            <ChevronRightIcon class="size-5 shrink-0 text-muted-foreground" />
          </RouterLink>

          <ul class="mt-4 grid grid-cols-3 gap-2 text-center text-xs">
            <li class="rounded-xl bg-secondary px-2 py-3"><HandIcon class="mx-auto mb-1.5 size-5 text-primary" />Handmade<span class="block text-muted-foreground">in {{ product.artisan.town?.name ?? 'Cebu' }}</span></li>
            <li class="rounded-xl bg-secondary px-2 py-3"><TruckIcon class="mx-auto mb-1.5 size-5 text-primary" />Ships from<span class="block text-muted-foreground">the maker</span></li>
            <li class="rounded-xl bg-secondary px-2 py-3"><BanknoteIcon class="mx-auto mb-1.5 size-5 text-primary" />Maya or<span class="block text-muted-foreground">cash on delivery</span></li>
          </ul>

          <!-- Details, collapsible -->
          <div class="mt-6 divide-y border-y">
            <details open class="group">
              <summary class="flex cursor-pointer list-none items-center justify-between py-4 font-medium">About this piece <ChevronDownIcon class="size-5 text-muted-foreground transition-transform group-open:rotate-180" /></summary>
              <p class="pb-5 leading-relaxed whitespace-pre-line text-muted-foreground">{{ product.description || 'The maker hasn\'t added a description yet.' }}</p>
            </details>
            <details v-if="product.materials" class="group">
              <summary class="flex cursor-pointer list-none items-center justify-between py-4 font-medium">Materials <ChevronDownIcon class="size-5 text-muted-foreground transition-transform group-open:rotate-180" /></summary>
              <p class="pb-5 text-muted-foreground">{{ product.materials }}</p>
            </details>
            <details class="group">
              <summary class="flex cursor-pointer list-none items-center justify-between py-4 font-medium">Delivery and payment <ChevronDownIcon class="size-5 text-muted-foreground transition-transform group-open:rotate-180" /></summary>
              <ul class="grid gap-2 pb-5 text-sm text-muted-foreground">
                <li>{{ product.artisan.shop_name }} packs and ships this piece. A flat shipping fee applies once per shop in your order.</li>
                <li>Pay online with Maya, or in cash when the parcel arrives.</li>
                <li>Track every parcel in My purchases.</li>
              </ul>
            </details>
          </div>
        </div>
      </div>

      <div class="px-4 md:px-0">
        <!-- Reviews -->
        <section id="reviews" class="mt-14 scroll-mt-24">
          <h2 class="font-display text-3xl font-medium">Reviews</h2>
          <div v-if="!reviews.length" class="mt-4 rounded-2xl bg-secondary p-6 text-sm text-muted-foreground">No reviews yet. Buyers can review a piece once it's delivered.</div>
          <div v-else class="mt-6 grid gap-8 md:grid-cols-[260px_1fr]">
            <div class="rounded-2xl bg-secondary p-5">
              <p class="font-display text-5xl">{{ rating!.toFixed(1) }}</p>
              <span class="mt-1 flex" :aria-label="`${rating!.toFixed(1)} out of 5`">
                <StarIcon v-for="n in 5" :key="n" :class="cn('size-4', n <= Math.round(rating!) ? 'fill-mango text-mango' : 'text-border')" />
              </span>
              <p class="mt-1 text-sm text-muted-foreground">{{ reviews.length }} {{ reviews.length === 1 ? 'review' : 'reviews' }}</p>
              <ul class="mt-4 grid gap-1.5 text-xs">
                <li v-for="b in breakdown" :key="b.stars" class="grid grid-cols-[1.25rem_1fr_1.5rem] items-center gap-2">
                  <span class="text-muted-foreground">{{ b.stars }}★</span>
                  <span class="h-1.5 overflow-hidden rounded-full bg-background"><span class="block h-full rounded-full bg-mango" :style="{ width: `${(b.count / reviews.length) * 100}%` }" /></span>
                  <span class="text-right text-muted-foreground tabular-nums">{{ b.count }}</span>
                </li>
              </ul>
            </div>
            <ul class="grid content-start gap-4 sm:grid-cols-2">
              <li v-for="r in reviews" :key="r.id" class="rounded-2xl border bg-card p-5">
                <span class="flex" :aria-label="`${r.rating} out of 5 stars`">
                  <StarIcon v-for="n in 5" :key="n" :class="cn('size-4', n <= r.rating ? 'fill-mango text-mango' : 'text-border')" />
                </span>
                <p class="mt-3 text-sm leading-relaxed">{{ r.comment || 'No comment.' }}</p>
                <p class="mt-3 text-xs text-muted-foreground">Verified buyer · {{ new Date(r.created_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) }}</p>
              </li>
            </ul>
          </div>
        </section>

        <!-- More from this maker -->
        <section v-if="fromMaker.length" class="mt-14">
          <div class="flex items-end justify-between gap-4">
            <h2 class="font-display text-2xl font-medium sm:text-3xl">More from {{ product.artisan.shop_name }}</h2>
            <RouterLink :to="`/artisans/${product.artisan.slug}`" class="flex shrink-0 items-center gap-1 text-sm font-medium text-primary">Visit shop <ChevronRightIcon class="size-4" /></RouterLink>
          </div>
          <div class="-mx-4 mt-5 flex snap-x scroll-px-4 gap-4 overflow-x-auto px-4 pb-2 [scrollbar-width:none] md:mx-0 md:scroll-px-0 md:px-0">
            <div v-for="p in fromMaker" :key="p.id" class="w-40 shrink-0 snap-start sm:w-52"><ProductCard :product="p" /></div>
          </div>
        </section>

        <!-- Similar pieces from other makers -->
        <section v-if="related.length" class="mt-14">
          <h2 class="font-display text-2xl font-medium sm:text-3xl">You may also like</h2>
          <div class="-mx-4 mt-5 flex snap-x scroll-px-4 gap-4 overflow-x-auto px-4 pb-2 [scrollbar-width:none] md:mx-0 md:scroll-px-0 md:px-0">
            <div v-for="p in related" :key="p.id" class="w-40 shrink-0 snap-start sm:w-52"><ProductCard :product="p" /></div>
          </div>
        </section>
      </div>

      <!-- Phones: buy bar above the home indicator -->
      <div class="pb-safe-4 fixed inset-x-0 bottom-0 z-30 flex items-center gap-3 border-t bg-background/95 px-4 pt-3 backdrop-blur md:hidden">
        <div class="min-w-0">
          <p class="text-xs text-muted-foreground">{{ qty > 1 ? `${qty} × ${peso(product.price)}` : 'Price' }}</p>
          <p class="font-display text-xl leading-tight">{{ peso(product.price * (product.stock ? qty : 1)) }}</p>
        </div>
        <Button size="lg" class="min-w-0 flex-1 px-4" :disabled="product.stock === 0" @click="addToCart">
          <ShoppingBagIcon /> {{ product.stock === 0 ? 'Sold out' : 'Add to cart' }}
        </Button>
      </div>
    </template>
  </div>
</template>
