<script setup lang="ts">
import type { CatalogProduct } from '@/lib/catalog'
import type { Town } from '@/types/database'
import { ArrowRightIcon, MapPinIcon, StoreIcon } from '@lucide/vue'
import L from 'leaflet'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ProductCard from '@/components/catalog/ProductCard.vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import { Button } from '@/components/ui/button'
import { fetchProducts } from '@/lib/catalog'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'
import 'leaflet/dist/leaflet.css'

interface Shop { id: string, shop_name: string, slug: string, photo_url: string | null, town_id: number | null }

const route = useRoute()
const router = useRouter()
const towns = ref<Town[]>([])
const shops = ref<Shop[]>([])
const products = ref<CatalogProduct[]>([])
const productTotal = ref(0)
const loadingProducts = ref(false)
const mapEl = ref<HTMLElement | null>(null)

let map: L.Map | null = null
const markers = new Map<number, L.Marker>()

const selectedName = computed(() => (typeof route.query.town === 'string' ? route.query.town : null))
const selected = computed(() => towns.value.find(t => t.name === selectedName.value) ?? null)
const shopsIn = (townId: number) => shops.value.filter(s => s.town_id === townId)

// Towns with shops first, then north to south.
const townList = computed(() => [...towns.value].sort((a, b) => (shopsIn(b.id).length > 0 ? 1 : 0) - (shopsIn(a.id).length > 0 ? 1 : 0) || b.lat - a.lat))

// Town names and descriptions are owner-edited text going into tooltip HTML.
const esc = (text: string) => text.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', '\'': '&#39;' })[c]!)

function pinIcon(town: Town, active: boolean) {
  const count = shopsIn(town.id).length
  return L.divIcon({
    className: '',
    iconSize: [36, 44],
    iconAnchor: [18, 42],
    html: `<span class="origin-pin${active ? ' is-active' : ''}${count ? '' : ' is-empty'}" aria-hidden="true"><span>${count || ''}</span></span>`,
  })
}

function drawMarkers() {
  if (!map) return
  for (const m of markers.values()) m.remove()
  markers.clear()
  for (const t of towns.value) {
    const marker = L.marker([t.lat, t.lng], { icon: pinIcon(t, t.name === selectedName.value), title: t.name, keyboard: true })
      .addTo(map)
      .bindTooltip(`<strong>${esc(t.name)}</strong><br>${esc(t.known_for)}`, { direction: 'top', offset: [0, -40] })
      .on('click', () => select(t.name))
    markers.set(t.id, marker)
  }
}

function select(name: string | null) {
  router.replace({ query: name ? { town: name } : {} })
}

async function loadTownProducts() {
  if (!selected.value) {
    products.value = []
    return
  }
  loadingProducts.value = true
  try {
    const res = await fetchProducts({ townId: selected.value.id }, 0, 6)
    products.value = res.products
    productTotal.value = res.total
  }
  finally {
    loadingProducts.value = false
  }
}

watch(selectedName, async () => {
  for (const t of towns.value) markers.get(t.id)?.setIcon(pinIcon(t, t.name === selectedName.value))
  if (selected.value && map) map.flyTo([selected.value.lat, selected.value.lng], Math.max(map.getZoom(), 10), { duration: 0.6 })
  await loadTownProducts()
  if (selected.value) document.getElementById('town-panel')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
})

onMounted(async () => {
  const [t, a] = await Promise.all([
    supabase.from('towns').select('*'),
    supabase.from('artisans').select('id, shop_name, slug, photo_url, town_id').eq('status', 'verified'),
  ])
  towns.value = t.data ?? []
  shops.value = a.data ?? []
  await nextTick()
  if (!mapEl.value) return

  map = L.map(mapEl.value, { scrollWheelZoom: false, zoomControl: true, attributionControl: true })
  // OpenStreetMap's standard tiles: free for light use with this attribution.
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 18,
  }).addTo(map)
  if (towns.value.length) map.fitBounds(L.latLngBounds(towns.value.map(x => [x.lat, x.lng] as [number, number])), { padding: [40, 40] })
  else map.setView([10.3, 123.85], 9)
  drawMarkers()
  await loadTownProducts()
})

onBeforeUnmount(() => {
  map?.remove()
  map = null
})
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-10">
    <header class="border-b pb-8">
      <p class="caps text-primary">Gikan sa · From the towns of Cebu</p>
      <h1 class="mt-2 font-display text-4xl font-medium sm:text-5xl">Shop by origin</h1>
      <p class="mt-2 max-w-2xl text-muted-foreground">Every town has a craft it's known for. Tap a pin to meet its makers and see what they make.</p>
    </header>

    <div class="mt-8 grid gap-6 lg:grid-cols-[1.4fr_1fr]">
      <div class="relative overflow-hidden rounded-2xl border lg:sticky lg:top-24 lg:self-start">
        <div ref="mapEl" class="h-[420px] w-full bg-secondary lg:h-[600px]" role="application" aria-label="Map of Cebu craft towns" />
        <div class="hablon pointer-events-none absolute inset-x-0 top-0 z-[500] h-1.5" aria-hidden="true" />
      </div>

      <div class="grid content-start gap-4">
        <section v-if="selected" id="town-panel" class="rounded-2xl border bg-card p-5">
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="caps flex items-center gap-1.5 text-primary"><MapPinIcon class="size-3.5" /> {{ selected.name }}</p>
              <h2 class="mt-2 font-display text-2xl font-medium">{{ selected.known_for || 'Local crafts' }}</h2>
            </div>
            <button class="text-xs text-muted-foreground hover:text-foreground" @click="select(null)">All towns</button>
          </div>

          <h3 class="mt-5 text-sm font-semibold">Makers here</h3>
          <ul v-if="shopsIn(selected.id).length" class="mt-2 grid gap-2">
            <li v-for="s in shopsIn(selected.id)" :key="s.id">
              <RouterLink :to="`/artisans/${s.slug}`" class="flex items-center gap-3 rounded-lg p-2 hover:bg-secondary">
                <img v-if="s.photo_url" :src="s.photo_url" alt="" class="size-10 rounded-full object-cover">
                <span v-else class="grid size-10 place-items-center rounded-full bg-primary font-display text-primary-foreground">{{ s.shop_name[0] }}</span>
                <span class="flex items-center gap-1 text-sm font-medium">{{ s.shop_name }} <VerifiedBadge compact /></span>
              </RouterLink>
            </li>
          </ul>
          <p v-else class="mt-2 text-sm text-muted-foreground">No verified shops from {{ selected.name }} yet. <RouterLink to="/sell" class="text-primary hover:underline">Are you a maker here?</RouterLink></p>
        </section>

        <section v-else class="rounded-2xl border bg-card p-5">
          <h2 class="font-display text-2xl font-medium">Choose a town</h2>
          <ul class="mt-4 grid gap-1">
            <li v-for="t in townList" :key="t.id">
              <button class="flex w-full items-center justify-between gap-3 rounded-lg px-3 py-2.5 text-left hover:bg-secondary" @click="select(t.name)">
                <span>
                  <span class="block text-sm font-medium">{{ t.name }}</span>
                  <span class="block text-xs text-muted-foreground">{{ t.known_for }}</span>
                </span>
                <span :class="cn('flex shrink-0 items-center gap-1 text-xs', shopsIn(t.id).length ? 'text-primary' : 'text-muted-foreground')">
                  <StoreIcon class="size-3.5" /> {{ shopsIn(t.id).length }}
                </span>
              </button>
            </li>
          </ul>
        </section>
      </div>
    </div>

    <section v-if="selected" class="mt-12">
      <div class="flex items-end justify-between gap-4">
        <h2 class="font-display text-3xl font-medium">Made in {{ selected.name }}</h2>
        <Button v-if="productTotal > products.length" as-child variant="outline" size="sm" class="rounded-full">
          <RouterLink :to="{ path: '/shop', query: { town: selected.name } }">See all {{ productTotal }} <ArrowRightIcon /></RouterLink>
        </Button>
      </div>
      <div v-if="loadingProducts" class="mt-6 grid grid-cols-2 gap-5 md:grid-cols-3"><div v-for="n in 3" :key="n" class="aspect-[4/5] animate-pulse rounded-xl bg-muted" /></div>
      <p v-else-if="!products.length" class="mt-4 text-sm text-muted-foreground">No pieces listed from {{ selected.name }} yet.</p>
      <div v-else class="mt-6 grid grid-cols-2 gap-x-5 gap-y-10 md:grid-cols-3">
        <ProductCard v-for="p in products" :key="p.id" :product="p" />
      </div>
    </section>
  </div>
</template>

<style>
/* Map pins: a clay drop with the town's shop count. */
.origin-pin {
  position: relative;
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 50% 50% 50% 0;
  transform: rotate(-45deg);
  background: var(--primary);
  border: 3px solid var(--background);
  box-shadow: 0 6px 14px -4px rgb(0 0 0 / 0.45);
  transition: transform 0.15s, background 0.15s;
  cursor: pointer;
}
.origin-pin > span {
  transform: rotate(45deg);
  font: 600 13px/1 var(--font-sans);
  color: var(--primary-foreground);
}
.origin-pin.is-empty { background: var(--clay-deep); opacity: 0.75; }
.origin-pin.is-active { background: var(--mango); transform: rotate(-45deg) scale(1.2); }
.origin-pin.is-active > span { color: var(--ink); }
.leaflet-container { font-family: var(--font-sans); }
</style>
