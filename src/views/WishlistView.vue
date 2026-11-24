<script setup lang="ts">
import type { CatalogProduct } from '@/lib/catalog'
import { HeartIcon } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import EmptyState from '@/components/catalog/EmptyState.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import { Button } from '@/components/ui/button'
import { fetchProductsByIds } from '@/lib/catalog'
import { useWishlistStore } from '@/stores/wishlist'

const wishlist = useWishlistStore()
const products = ref<CatalogProduct[]>([])
const loading = ref(true)

// Reload when the saved set changes; unsaving from a card removes it here too.
watch(() => [...wishlist.ids].join(), async () => {
  try {
    products.value = await fetchProductsByIds([...wishlist.ids])
  }
  finally {
    loading.value = false
  }
}, { immediate: true })

// Saved pieces that were hidden or whose shop was paused don't come back.
const unavailable = computed(() => wishlist.ids.size - products.value.length)
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-10">
    <h1 class="font-display text-4xl font-medium sm:text-5xl">Saved pieces</h1>
    <p class="mt-2 text-muted-foreground">Crafts you've hearted, ready when you are.</p>

    <div v-if="loading" class="mt-8 grid grid-cols-2 gap-5 md:grid-cols-4"><div v-for="n in 4" :key="n" class="aspect-[4/5] animate-pulse rounded-xl bg-muted" /></div>
    <EmptyState v-else-if="!products.length" class="mt-8" title="Nothing saved yet" body="Tap the heart on any piece to keep it here.">
      <Button as-child><RouterLink to="/shop"><HeartIcon /> Find something to love</RouterLink></Button>
    </EmptyState>
    <template v-else>
      <div class="mt-8 grid grid-cols-2 gap-x-5 gap-y-10 md:grid-cols-4">
        <ProductCard v-for="p in products" :key="p.id" :product="p" />
      </div>
      <p v-if="unavailable > 0" class="mt-8 text-sm text-muted-foreground">{{ unavailable }} saved {{ unavailable === 1 ? 'piece is' : 'pieces are' }} no longer available.</p>
    </template>
  </div>
</template>
