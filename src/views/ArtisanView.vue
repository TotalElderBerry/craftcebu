<script setup lang="ts">
import type { CatalogProduct, ShopArtisan } from '@/lib/catalog'
import { CalendarIcon, MapPinIcon } from '@lucide/vue'
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import EmptyState from '@/components/catalog/EmptyState.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import HablonBand from '@/components/HablonBand.vue'
import { Button } from '@/components/ui/button'
import { fetchArtisan, fetchProducts } from '@/lib/catalog'
import { yearsInCraft } from '@/lib/format'

const route = useRoute()
const artisan = ref<ShopArtisan | null>(null)
const products = ref<CatalogProduct[]>([])
const loading = ref(true)

async function load(slug: string) {
  loading.value = true
  try {
    artisan.value = await fetchArtisan(slug)
    if (artisan.value) {
      document.title = `${artisan.value.shop_name} · CraftCebu`
      products.value = (await fetchProducts({ artisanId: artisan.value.id }, 0, 48)).products
    }
  }
  finally {
    loading.value = false
  }
}

watch(() => route.params.slug, slug => typeof slug === 'string' && load(slug), { immediate: true })
</script>

<template>
  <div v-if="loading" class="mx-auto max-w-6xl px-4 py-12">
    <div class="h-64 animate-pulse rounded-2xl bg-muted" />
  </div>

  <div v-else-if="!artisan" class="mx-auto max-w-6xl px-4 py-12">
    <EmptyState title="Shop not found" body="This shop may not be verified yet, or its link has changed.">
      <Button as-child variant="outline"><RouterLink to="/artisans">See all makers</RouterLink></Button>
    </EmptyState>
  </div>

  <template v-else>
    <!-- Maker header: the person comes first, then the products -->
    <section class="clay-panel">
      <div class="mx-auto grid max-w-6xl items-center gap-10 px-4 py-14 md:grid-cols-[auto_1fr]">
        <div class="relative mx-auto">
          <div class="absolute -inset-2.5 rounded-t-[999px] rounded-b-2xl border border-white/30" aria-hidden="true" />
          <img v-if="artisan.photo_url" :src="artisan.photo_url" :alt="artisan.shop_name" class="relative h-64 w-48 rounded-t-[999px] rounded-b-2xl object-cover">
          <div v-else class="relative grid h-64 w-48 place-items-center rounded-t-[999px] rounded-b-2xl bg-white/10 font-display text-7xl">{{ artisan.shop_name[0] }}</div>
        </div>
        <div>
          <VerifiedBadge />
          <h1 class="mt-4 font-display text-4xl font-medium sm:text-6xl">{{ artisan.shop_name }}</h1>
          <div class="mt-4 flex flex-wrap gap-x-6 gap-y-2 text-sm opacity-85">
            <span v-if="artisan.town" class="flex items-center gap-1.5"><MapPinIcon class="size-4 text-mango" /> {{ artisan.town.name }}, Cebu</span>
            <span v-if="yearsInCraft(artisan.craft_since)" class="flex items-center gap-1.5">
              <CalendarIcon class="size-4 text-mango" /> In the craft since {{ artisan.craft_since }} ({{ yearsInCraft(artisan.craft_since) }} years)
            </span>
          </div>
          <p v-if="artisan.town?.known_for" class="mt-2 text-sm opacity-70">{{ artisan.town.name }} is known for {{ artisan.town.known_for.toLowerCase() }}.</p>
        </div>
      </div>
      <HablonBand />
    </section>

    <div class="mx-auto grid max-w-6xl gap-12 px-4 py-14 lg:grid-cols-[1fr_2fr]">
      <section>
        <p class="caps text-primary">Ang istorya · The story</p>
        <p class="mt-4 font-display text-xl leading-relaxed whitespace-pre-line">{{ artisan.story || 'This maker hasn\'t shared their story yet.' }}</p>
      </section>

      <section>
        <div class="flex items-baseline justify-between">
          <h2 class="font-display text-3xl font-medium">From this shop</h2>
          <span class="text-sm text-muted-foreground">{{ products.length }} {{ products.length === 1 ? 'piece' : 'pieces' }}</span>
        </div>
        <EmptyState v-if="!products.length" class="mt-6" title="Nothing listed yet" body="Check back soon. This maker is preparing their first pieces." />
        <div v-else class="mt-6 grid grid-cols-2 gap-x-5 gap-y-10 md:grid-cols-3">
          <ProductCard v-for="p in products" :key="p.id" :product="p" />
        </div>
      </section>
    </div>
  </template>
</template>
