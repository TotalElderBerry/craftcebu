<script setup lang="ts">
import type { CatalogProduct } from '@/lib/catalog'
import { CheckIcon, MapPinIcon, PlusIcon, StarIcon } from '@lucide/vue'
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import WishlistButton from '@/components/WishlistButton.vue'
import { coverImage } from '@/lib/catalog'
import { peso } from '@/lib/format'
import { categoryImages, images } from '@/lib/images'
import { cn } from '@/lib/utils'
import { useCartStore } from '@/stores/cart'

const props = defineProps<{ product: CatalogProduct }>()
const cart = useCartStore()
const router = useRouter()

// Until a shop uploads photos, show the craft's stand-in photo.
const src = coverImage(props.product) ?? categoryImages[props.product.category?.slug ?? ''] ?? images.wovenTexture
const inCart = computed(() => cart.lines.find(l => l.productId === props.product.id)?.qty ?? 0)
const canAdd = computed(() => props.product.stock > inCart.value)

// One tap adds a single piece, like a shopping app's "+" button.
function quickAdd() {
  if (!canAdd.value) {
    toast.info(props.product.stock === 0 ? 'This piece is sold out.' : 'You already have every available piece in your cart.')
    return
  }
  cart.add(props.product, 1)
  toast.success(`Added ${props.product.name}`, { action: { label: 'View cart', onClick: () => router.push('/cart') } })
}
</script>

<template>
  <article class="group relative">
    <div class="relative overflow-hidden rounded-2xl bg-muted">
      <img :src="src" :alt="product.name" loading="lazy" class="aspect-[4/5] w-full object-cover transition-transform duration-500 group-hover:scale-[1.04]">
      <span v-if="product.artisan.town" class="absolute top-2.5 left-2.5 flex max-w-[calc(100%-3.75rem)] items-center gap-1 rounded-full bg-background/90 px-2.5 py-1 text-xs font-medium backdrop-blur-sm">
        <MapPinIcon class="size-3 shrink-0 text-primary" /> <span class="truncate">{{ product.artisan.town.name }}</span>
      </span>
      <span v-if="product.stock === 0" class="absolute bottom-2.5 left-2.5 rounded-full bg-ink/85 px-2.5 py-1 text-xs font-medium text-white">Sold out</span>
      <!-- Heart and quick add sit above the card's full-size link so they get the tap -->
      <WishlistButton :product-id="product.id" :product-name="product.name" class="absolute top-2.5 right-2.5 z-10" />
      <button
        v-if="product.stock > 0"
        type="button"
        :aria-label="inCart ? `${product.name}: ${inCart} in cart, add another` : `Add ${product.name} to cart`"
        :class="cn('absolute right-2.5 bottom-2.5 z-10 grid size-10 place-items-center rounded-full shadow-md transition-transform active:scale-90', inCart ? 'bg-mango text-ink' : 'bg-primary text-primary-foreground')"
        @click.prevent.stop="quickAdd"
      >
        <CheckIcon v-if="inCart && !canAdd" class="size-5" />
        <PlusIcon v-else class="size-5" />
        <span v-if="inCart" class="absolute -top-1 -right-1 grid min-w-5 place-items-center rounded-full bg-ink px-1 text-[0.65rem] font-bold text-white">{{ inCart }}</span>
      </button>
    </div>
    <div class="mt-3">
      <h3 class="line-clamp-2 leading-snug font-medium">
        <RouterLink :to="`/product/${product.slug}`" class="after:absolute after:inset-0">{{ product.name }}</RouterLink>
      </h3>
      <p class="mt-0.5 flex min-w-0 items-center gap-1 text-sm text-muted-foreground">
        <span class="truncate">{{ product.artisan.shop_name }}</span> <VerifiedBadge compact class="shrink-0" />
      </p>
      <div class="mt-1.5 flex items-center justify-between gap-2">
        <p class="font-display text-lg font-medium">{{ peso(product.price) }}</p>
        <span v-if="product.review_count" class="flex items-center gap-1 text-xs text-muted-foreground" :aria-label="`Rated ${product.rating!.toFixed(1)} out of 5 from ${product.review_count} reviews`">
          <StarIcon class="size-3.5 fill-mango text-mango" /> {{ product.rating!.toFixed(1) }}
        </span>
      </div>
    </div>
  </article>
</template>
