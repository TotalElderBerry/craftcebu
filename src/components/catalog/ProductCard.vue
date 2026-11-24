<script setup lang="ts">
import type { CatalogProduct } from '@/lib/catalog'
import { MapPinIcon, StarIcon } from '@lucide/vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import WishlistButton from '@/components/WishlistButton.vue'
import { coverImage } from '@/lib/catalog'
import { peso } from '@/lib/format'
import { categoryImages, images } from '@/lib/images'

const props = defineProps<{ product: CatalogProduct }>()

// Until a shop uploads photos, show the craft's stand-in photo.
const src = coverImage(props.product) ?? categoryImages[props.product.category?.slug ?? ''] ?? images.wovenTexture
</script>

<template>
  <article class="group relative">
    <div class="relative overflow-hidden rounded-xl bg-muted">
      <img :src="src" :alt="product.name" loading="lazy" class="aspect-[4/5] w-full object-cover transition-transform duration-500 group-hover:scale-[1.04]">
      <span v-if="product.artisan.town" class="absolute top-3 left-3 flex max-w-[calc(100%-4rem)] items-center gap-1 rounded-full bg-background/90 px-2.5 py-1 text-xs font-medium">
        <MapPinIcon class="size-3 shrink-0 text-primary" /> <span class="truncate">{{ product.artisan.town.name }}</span>
      </span>
      <span v-if="product.stock === 0" class="absolute right-3 bottom-3 rounded-full bg-ink/85 px-2.5 py-1 text-xs font-medium text-white">Sold out</span>
      <!-- Above the card's full-size link so the heart gets the click -->
      <WishlistButton :product-id="product.id" :product-name="product.name" class="absolute top-3 right-3 z-10" />
    </div>
    <div class="mt-3">
      <h3 class="font-medium leading-snug">
        <RouterLink :to="`/product/${product.slug}`" class="after:absolute after:inset-0">{{ product.name }}</RouterLink>
      </h3>
      <p class="mt-0.5 flex items-center gap-1 text-sm text-muted-foreground">
        {{ product.artisan.shop_name }} <VerifiedBadge compact />
      </p>
      <div class="mt-1.5 flex items-center justify-between gap-2">
        <p class="font-display text-lg font-medium">{{ peso(product.price) }}</p>
        <span v-if="product.review_count" class="flex items-center gap-1 text-xs text-muted-foreground" :aria-label="`Rated ${product.rating!.toFixed(1)} out of 5 from ${product.review_count} reviews`">
          <StarIcon class="size-3.5 fill-mango text-mango" /> {{ product.rating!.toFixed(1) }} ({{ product.review_count }})
        </span>
      </div>
    </div>
  </article>
</template>
