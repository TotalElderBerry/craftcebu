<script setup lang="ts">
import type { CatalogFilters, CatalogProduct, ShopArtisan, SortKey } from '@/lib/catalog'
import { ArrowRightIcon, ChevronDownIcon, MapPinIcon, SearchIcon, SlidersHorizontalIcon, XIcon } from '@lucide/vue'
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/catalog/EmptyState.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import WovenMark from '@/components/WovenMark.vue'
import { fetchArtisans, fetchFacets, fetchProducts } from '@/lib/catalog'
import { categoryImages, images } from '@/lib/images'
import { isSupabaseConfigured } from '@/lib/supabase'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const facets = ref<Awaited<ReturnType<typeof fetchFacets>>>({ towns: [], categories: [] })
const makers = ref<ShopArtisan[]>([])
const products = ref<CatalogProduct[]>([])
const total = ref(0)
const page = ref(0)
const loading = ref(true)
const error = ref('')
const showFilters = ref(false)

// The URL is the source of truth for filters, so results can be shared and the
// back button works.
const str = (v: unknown) => (typeof v === 'string' && v ? v : undefined)
const num = (v: unknown) => (typeof v === 'string' && v !== '' && !Number.isNaN(Number(v)) ? Number(v) : undefined)
const state = computed(() => ({
  q: str(route.query.q),
  category: str(route.query.category),
  town: str(route.query.town),
  min: num(route.query.min),
  max: num(route.query.max),
  sort: (str(route.query.sort) ?? 'newest') as SortKey,
}))

function setQuery(patch: Record<string, string | number | undefined>) {
  const next = { ...route.query, ...patch }
  for (const key of Object.keys(next)) {
    if (next[key] === undefined || next[key] === '') delete next[key]
  }
  router.replace({ query: next })
}

const search = ref(state.value.q ?? '')
const minInput = ref(state.value.min?.toString() ?? '')
const maxInput = ref(state.value.max?.toString() ?? '')
let searchTimer: ReturnType<typeof setTimeout> | undefined
watch(search, (v) => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => setQuery({ q: v.trim() || undefined }), 300)
})
watch(() => route.query.q, (v) => {
  if ((v ?? '') !== search.value.trim()) search.value = typeof v === 'string' ? v : ''
})

function applyPrice() {
  setQuery({ min: minInput.value || undefined, max: maxInput.value || undefined })
  showFilters.value = false
}

const townId = computed(() => facets.value.towns.find(t => t.name === state.value.town)?.id)

async function load(reset: boolean) {
  if (!isSupabaseConfigured) {
    loading.value = false
    return
  }
  if (reset) page.value = 0
  loading.value = true
  error.value = ''
  const filters: CatalogFilters = {
    q: state.value.q,
    category: state.value.category,
    townId: townId.value,
    minPrice: state.value.min,
    maxPrice: state.value.max,
    sort: state.value.sort,
  }
  try {
    const res = await fetchProducts(filters, page.value)
    products.value = reset ? res.products : [...products.value, ...res.products]
    total.value = res.total
  }
  catch (e) {
    // Supabase errors are plain objects with a message, not Error instances.
    error.value = (e as { message?: string })?.message ?? 'Could not load products'
  }
  finally {
    loading.value = false
  }
}

function loadMore() {
  page.value++
  load(false)
}

onMounted(async () => {
  if (isSupabaseConfigured) {
    const [f, m] = await Promise.all([fetchFacets(), fetchArtisans().catch(() => [])])
    facets.value = f
    makers.value = m
  }
  await load(true)
})
watch(state, () => load(true))

// Keep the selected craft visible in the rail, even when it's far along it.
const rail = ref<HTMLElement | null>(null)
watch(() => [state.value.category, facets.value.categories.length], async () => {
  await nextTick()
  const el = rail.value?.querySelector<HTMLElement>('[aria-pressed="true"]')
  // Set the rail's own scroll position; scrollIntoView would also move the
  // page and gets cancelled by the router's scroll-to-top.
  if (rail.value && el) rail.value.scrollLeft = el.offsetLeft - rail.value.clientWidth / 2 + el.offsetWidth / 2
}, { flush: 'post' })

const filtered = computed(() => !!(state.value.q || state.value.category || state.value.town || state.value.min != null || state.value.max != null))
const priceSet = computed(() => state.value.min != null || state.value.max != null)

const activeChips = computed(() => {
  const chips: { label: string, clear: Record<string, undefined> }[] = []
  if (state.value.q) chips.push({ label: `“${state.value.q}”`, clear: { q: undefined } })
  if (state.value.category) {
    const name = facets.value.categories.find(c => c.slug === state.value.category)?.name ?? state.value.category
    chips.push({ label: name, clear: { category: undefined } })
  }
  if (state.value.town) chips.push({ label: state.value.town, clear: { town: undefined } })
  if (priceSet.value) {
    chips.push({ label: `₱${state.value.min ?? 0} – ${state.value.max != null ? `₱${state.value.max}` : 'any'}`, clear: { min: undefined, max: undefined } })
  }
  return chips
})

function clearAll() {
  search.value = ''
  minInput.value = ''
  maxInput.value = ''
  router.replace({ query: {} })
}

const sorts: { key: SortKey, label: string }[] = [
  { key: 'newest', label: 'Newest' },
  { key: 'price-asc', label: 'Lowest price' },
  { key: 'price-desc', label: 'Highest price' },
]

// Short labels for the round craft icons.
const shortName = (name: string) => name.replace(/ and .*/, '')
const firstName = computed(() => auth.profile?.full_name?.split(' ')[0])
const selectedCraft = computed(() => facets.value.categories.find(c => c.slug === state.value.category))
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 pt-6 pb-12 md:pt-10">
    <!-- Greeting and search -->
    <header>
      <p class="caps text-primary">Maayong adlaw{{ firstName ? `, ${firstName}` : '' }}</p>
      <h1 class="mt-2 font-display text-3xl leading-tight font-medium sm:text-5xl">
        {{ selectedCraft ? selectedCraft.name : 'What are you looking for?' }}
      </h1>
      <div class="mt-5 flex gap-2">
        <label class="flex h-12 min-w-0 flex-1 items-center gap-2 rounded-full border bg-card px-4 text-sm shadow-[0_1px_2px_rgba(0,0,0,0.04)] focus-within:border-primary">
          <SearchIcon class="size-4 shrink-0 text-muted-foreground" />
          <input v-model="search" type="search" enterkeyhint="search" placeholder="Search hablon, rattan, guitars…" aria-label="Search products" class="w-full min-w-0 bg-transparent outline-none placeholder:text-muted-foreground">
          <button v-if="search" type="button" class="-mr-2 grid size-9 shrink-0 place-items-center rounded-full text-muted-foreground hover:bg-secondary" aria-label="Clear search" @click="search = ''">
            <XIcon class="size-4" />
          </button>
        </label>
        <Button variant="outline" size="icon" class="relative size-12 shrink-0" aria-label="Price and sort" @click="showFilters = true">
          <SlidersHorizontalIcon class="size-5" />
          <span v-if="priceSet || state.sort !== 'newest'" class="absolute top-2 right-2 size-2 rounded-full bg-primary" aria-hidden="true" />
        </Button>
      </div>
    </header>

    <!-- Craft rail: round photos, one per craft -->
    <nav ref="rail" class="-mx-4 mt-6 overflow-x-auto px-4 [scrollbar-width:none]" aria-label="Crafts">
      <ul class="flex gap-4 py-1 pl-1 sm:gap-6">
        <li>
          <button class="group flex w-16 flex-col items-center gap-2 sm:w-20" :aria-pressed="!state.category" @click="setQuery({ category: undefined })">
            <span :class="cn('grid size-16 place-items-center rounded-full bg-secondary ring-offset-2 ring-offset-background transition sm:size-20', !state.category ? 'ring-2 ring-primary' : 'group-hover:ring-2 group-hover:ring-border')">
              <WovenMark class="size-8" />
            </span>
            <span :class="cn('text-center text-xs leading-tight', !state.category ? 'font-semibold text-foreground' : 'text-muted-foreground')">All</span>
          </button>
        </li>
        <li v-for="c in facets.categories" :key="c.slug">
          <button class="group flex w-16 flex-col items-center gap-2 sm:w-20" :aria-pressed="state.category === c.slug" @click="setQuery({ category: state.category === c.slug ? undefined : c.slug })">
            <span :class="cn('block size-16 overflow-hidden rounded-full bg-muted ring-offset-2 ring-offset-background transition sm:size-20', state.category === c.slug ? 'ring-2 ring-primary' : 'group-hover:ring-2 group-hover:ring-border')">
              <img :src="categoryImages[c.slug] ?? images.wovenTexture" alt="" class="size-full object-cover transition-transform duration-300 group-hover:scale-110">
            </span>
            <span :class="cn('line-clamp-2 text-center text-xs leading-tight', state.category === c.slug ? 'font-semibold text-foreground' : 'text-muted-foreground')">{{ shortName(c.name) }}</span>
          </button>
        </li>
      </ul>
    </nav>

    <!-- Town chips -->
    <div class="-mx-4 mt-5 flex items-center gap-2 overflow-x-auto px-4 pb-1 [scrollbar-width:none]" role="group" aria-label="Towns">
      <span class="caps shrink-0 pr-1 text-muted-foreground">Gikan sa</span>
      <button
        v-for="t in facets.towns"
        :key="t.id"
        :aria-pressed="state.town === t.name"
        :class="cn('flex h-9 shrink-0 items-center gap-1.5 rounded-full border px-3.5 text-sm transition-colors', state.town === t.name ? 'border-ink bg-ink text-background' : 'bg-card hover:border-foreground')"
        @click="setQuery({ town: state.town === t.name ? undefined : t.name })"
      >
        <MapPinIcon :class="cn('size-3.5', state.town === t.name ? 'text-mango' : 'text-primary')" /> {{ t.name }}
      </button>
    </div>

    <!-- Meet the makers: only while browsing everything -->
    <section v-if="!filtered && makers.length" class="mt-10" aria-labelledby="makers-heading">
      <div class="flex items-end justify-between gap-4">
        <h2 id="makers-heading" class="font-display text-2xl font-medium sm:text-3xl">Meet the makers</h2>
        <RouterLink to="/artisans" class="flex shrink-0 items-center gap-1 text-sm font-medium text-primary">All makers <ArrowRightIcon class="size-4" /></RouterLink>
      </div>
      <ul class="-mx-4 mt-4 flex snap-x scroll-px-4 gap-3 overflow-x-auto px-4 pb-2 [scrollbar-width:none]">
        <li v-for="m in makers" :key="m.id" class="w-56 shrink-0 snap-start sm:w-64">
          <RouterLink :to="`/artisans/${m.slug}`" class="group relative block overflow-hidden rounded-2xl">
            <img :src="m.photo_url ?? images.weavingHands" :alt="m.shop_name" class="aspect-[4/3] w-full object-cover transition-transform duration-500 group-hover:scale-105">
            <span class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/15 to-transparent" aria-hidden="true" />
            <span class="absolute inset-x-0 bottom-0 p-4 text-white">
              <span class="flex items-center gap-1.5 font-display text-lg leading-tight">{{ m.shop_name }} <VerifiedBadge compact class="text-mango" /></span>
              <span class="mt-0.5 flex items-center gap-1 text-xs opacity-85"><MapPinIcon class="size-3" /> {{ m.town?.name ?? 'Cebu' }}</span>
            </span>
          </RouterLink>
        </li>
      </ul>
    </section>

    <!-- Results -->
    <section class="mt-10" aria-live="polite" aria-labelledby="results-heading">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id="results-heading" class="font-display text-2xl font-medium sm:text-3xl">
          {{ filtered ? 'Results' : 'All pieces' }}
          <span class="ml-1 align-middle font-sans text-sm font-normal text-muted-foreground">{{ loading && !products.length ? '' : `${total} ${total === 1 ? 'piece' : 'pieces'}` }}</span>
        </h2>
        <label class="relative hidden sm:block">
          <span class="sr-only">Sort</span>
          <select
            :value="state.sort"
            aria-label="Sort products"
            class="h-10 w-44 appearance-none rounded-full border bg-card pr-10 pl-4 text-sm font-medium"
            @change="setQuery({ sort: ($event.target as HTMLSelectElement).value === 'newest' ? undefined : ($event.target as HTMLSelectElement).value })"
          >
            <option v-for="s in sorts" :key="s.key" :value="s.key">{{ s.label }}</option>
          </select>
          <ChevronDownIcon class="pointer-events-none absolute top-1/2 right-4 size-4 -translate-y-1/2 text-muted-foreground" />
        </label>
      </div>

      <div v-if="activeChips.length" class="mt-3 flex flex-wrap items-center gap-2 text-sm">
        <button v-for="chip in activeChips" :key="chip.label" class="flex h-9 items-center gap-1 rounded-full bg-secondary px-3 font-medium hover:bg-accent" @click="setQuery(chip.clear)">
          {{ chip.label }} <XIcon class="size-3.5" />
        </button>
        <button class="h-9 px-2 text-primary hover:underline" @click="clearAll">Clear all</button>
      </div>

      <p v-if="error" class="mt-6 rounded-lg border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">{{ error }}</p>

      <div v-if="loading && !products.length" class="mt-6 grid grid-cols-2 gap-x-4 gap-y-8 md:grid-cols-3 lg:grid-cols-4">
        <div v-for="n in 8" :key="n">
          <div class="aspect-[4/5] animate-pulse rounded-2xl bg-muted" />
          <div class="mt-3 h-4 w-3/4 animate-pulse rounded bg-muted" />
          <div class="mt-2 h-4 w-1/3 animate-pulse rounded bg-muted" />
        </div>
      </div>

      <EmptyState
        v-else-if="!products.length && !error"
        class="mt-6"
        :title="filtered ? 'Walay nakit-an · Nothing found' : 'No crafts listed yet'"
        :body="filtered ? 'Try another craft or town, or clear your filters.' : 'Verified artisans\' products will appear here as soon as they list them.'"
      >
        <Button v-if="filtered" variant="outline" @click="clearAll">Clear filters</Button>
      </EmptyState>

      <template v-else>
        <div class="mt-6 grid grid-cols-2 gap-x-4 gap-y-8 md:grid-cols-3 lg:grid-cols-4">
          <ProductCard v-for="p in products" :key="p.id" :product="p" />
        </div>
        <div v-if="products.length < total" class="mt-12 flex justify-center">
          <Button variant="outline" size="lg" :disabled="loading" @click="loadMore">{{ loading ? 'Loading…' : 'Show more' }}</Button>
        </div>
      </template>
    </section>

    <!-- Price and sort sheet -->
    <Sheet v-model:open="showFilters">
      <SheetContent side="bottom" class="gap-0 rounded-t-2xl p-0 sm:mx-auto sm:max-w-lg">
        <SheetHeader class="border-b px-5 py-4">
          <SheetTitle class="font-display text-xl font-medium">Price and sort</SheetTitle>
        </SheetHeader>
        <div class="grid gap-7 px-5 py-6">
          <section>
            <h3 class="caps text-muted-foreground">Sort by</h3>
            <div class="mt-3 grid grid-cols-3 gap-2" role="radiogroup" aria-label="Sort by">
              <button
                v-for="s in sorts"
                :key="s.key"
                role="radio"
                :aria-checked="state.sort === s.key"
                :class="cn('h-11 rounded-full border text-sm font-medium transition-colors', state.sort === s.key ? 'border-primary bg-primary text-primary-foreground' : 'hover:border-foreground')"
                @click="setQuery({ sort: s.key === 'newest' ? undefined : s.key })"
              >
                {{ s.label }}
              </button>
            </div>
          </section>
          <section>
            <h3 class="caps text-muted-foreground">Price (₱)</h3>
            <form id="price-form" class="mt-3 flex items-center gap-2" @submit.prevent="applyPrice">
              <Input v-model="minInput" type="number" inputmode="numeric" min="0" placeholder="Min" aria-label="Minimum price" />
              <span class="text-muted-foreground">–</span>
              <Input v-model="maxInput" type="number" inputmode="numeric" min="0" placeholder="Max" aria-label="Maximum price" />
            </form>
          </section>
        </div>
        <div class="flex gap-2 border-t px-5 py-3">
          <Button variant="outline" class="flex-1" @click="minInput = ''; maxInput = ''; setQuery({ min: undefined, max: undefined, sort: undefined })">Reset</Button>
          <Button type="submit" form="price-form" class="flex-1">Show {{ total }} {{ total === 1 ? 'piece' : 'pieces' }}</Button>
        </div>
      </SheetContent>
    </Sheet>
  </div>
</template>
