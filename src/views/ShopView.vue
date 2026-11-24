<script setup lang="ts">
import type { CatalogFilters, CatalogProduct, SortKey } from '@/lib/catalog'
import { ChevronDownIcon, SearchIcon, SlidersHorizontalIcon, XIcon } from '@lucide/vue'
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/catalog/EmptyState.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import ShopFilters from '@/components/catalog/ShopFilters.vue'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { fetchFacets, fetchProducts } from '@/lib/catalog'
import { isSupabaseConfigured } from '@/lib/supabase'

const route = useRoute()
const router = useRouter()

const facets = ref<Awaited<ReturnType<typeof fetchFacets>>>({ towns: [], categories: [] })
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
  if (isSupabaseConfigured) facets.value = await fetchFacets()
  await load(true)
})
watch(state, () => load(true))

const activeChips = computed(() => {
  const chips: { label: string, clear: Record<string, undefined> }[] = []
  if (state.value.q) chips.push({ label: `“${state.value.q}”`, clear: { q: undefined } })
  if (state.value.category) {
    const name = facets.value.categories.find(c => c.slug === state.value.category)?.name ?? state.value.category
    chips.push({ label: name, clear: { category: undefined } })
  }
  if (state.value.town) chips.push({ label: state.value.town, clear: { town: undefined } })
  if (state.value.min != null || state.value.max != null) {
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
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-10">
    <header class="flex flex-col gap-2 border-b pb-8">
      <p class="caps text-primary">Mga Craft · The catalog</p>
      <h1 class="font-display text-4xl font-medium sm:text-5xl">Shop the crafts</h1>
      <p class="text-muted-foreground">Every piece below is made and sold by a verified Cebuano artisan.</p>
    </header>

    <div class="mt-8 grid gap-10 lg:grid-cols-[220px_1fr]">
      <!-- Filters: sidebar on desktop -->
      <aside class="hidden lg:block" aria-label="Filters">
        <div class="lg:sticky lg:top-24">
          <ShopFilters v-model:min="minInput" v-model:max="maxInput" :categories="facets.categories" :towns="facets.towns" :category="state.category" :town="state.town" @set="setQuery" @apply-price="applyPrice" />
        </div>
      </aside>

      <!-- ...and a bottom sheet on phones -->
      <Sheet v-model:open="showFilters">
        <SheetContent side="bottom" class="max-h-[85svh] gap-0 overflow-y-auto rounded-t-2xl p-0">
          <SheetHeader class="border-b px-5 py-4">
            <SheetTitle class="font-display text-xl font-medium">Filters</SheetTitle>
          </SheetHeader>
          <div class="px-5 py-6">
            <ShopFilters v-model:min="minInput" v-model:max="maxInput" :categories="facets.categories" :towns="facets.towns" :category="state.category" :town="state.town" @set="setQuery" @apply-price="applyPrice" />
          </div>
          <div class="sticky bottom-0 flex gap-2 border-t bg-popover px-5 py-3">
            <Button variant="outline" class="flex-1" @click="clearAll">Clear</Button>
            <Button class="flex-1" @click="showFilters = false">Show {{ total }} {{ total === 1 ? 'piece' : 'pieces' }}</Button>
          </div>
        </SheetContent>
      </Sheet>

      <!-- Results -->
      <section aria-live="polite">
        <!-- Phones: search gets its own full-width row, Filters and Sort share the next.
             Wider screens: one row. -->
        <div class="grid gap-3 sm:flex sm:items-center">
          <label class="flex h-12 min-w-0 items-center gap-2 rounded-full border bg-card px-4 text-sm sm:h-11 sm:flex-1">
            <SearchIcon class="size-4 shrink-0 text-muted-foreground" />
            <input v-model="search" type="search" enterkeyhint="search" placeholder="Search hablon, rattan, guitars…" aria-label="Search products" class="w-full min-w-0 bg-transparent outline-none placeholder:text-muted-foreground">
          </label>
          <div class="grid grid-cols-2 gap-3 sm:flex sm:shrink-0 sm:items-center">
            <Button variant="outline" class="h-11 w-full lg:hidden" :aria-expanded="showFilters" @click="showFilters = true">
              <SlidersHorizontalIcon /> Filters
            </Button>
            <label class="flex items-center gap-2 text-sm text-muted-foreground">
              <span class="sr-only sm:not-sr-only">Sort</span>
              <span class="relative w-full sm:w-auto">
                <!-- appearance-none drops the phone's native box so it matches the other controls -->
                <select
                  :value="state.sort"
                  aria-label="Sort products"
                  class="h-11 w-full appearance-none rounded-full border bg-card pr-10 pl-4 text-sm font-medium text-foreground sm:w-48"
                  @change="setQuery({ sort: ($event.target as HTMLSelectElement).value === 'newest' ? undefined : ($event.target as HTMLSelectElement).value })"
                >
                  <option v-for="s in sorts" :key="s.key" :value="s.key">{{ s.label }}</option>
                </select>
                <ChevronDownIcon class="pointer-events-none absolute top-1/2 right-4 size-4 -translate-y-1/2 text-muted-foreground" />
              </span>
            </label>
          </div>
        </div>

        <div class="mt-4 flex flex-wrap items-center gap-2 text-sm">
          <span class="text-muted-foreground">{{ loading && !products.length ? 'Loading…' : `${total} ${total === 1 ? 'piece' : 'pieces'}` }}</span>
          <button v-for="chip in activeChips" :key="chip.label" class="flex h-9 items-center gap-1 rounded-full bg-secondary px-3 font-medium hover:bg-accent" @click="setQuery(chip.clear)">
            {{ chip.label }} <XIcon class="size-3.5" />
          </button>
          <button v-if="activeChips.length" class="h-9 px-2 text-primary hover:underline" @click="clearAll">Clear all</button>
        </div>

        <p v-if="error" class="mt-8 rounded-lg border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">{{ error }}</p>

        <div v-if="loading && !products.length" class="mt-8 grid grid-cols-2 gap-x-5 gap-y-8 md:grid-cols-3">
          <div v-for="n in 6" :key="n">
            <div class="aspect-[4/5] animate-pulse rounded-xl bg-muted" />
            <div class="mt-3 h-4 w-3/4 animate-pulse rounded bg-muted" />
            <div class="mt-2 h-4 w-1/3 animate-pulse rounded bg-muted" />
          </div>
        </div>

        <EmptyState
          v-else-if="!products.length && !error"
          class="mt-8"
          :title="activeChips.length ? 'Walay nakit-an · Nothing found' : 'No crafts listed yet'"
          :body="activeChips.length ? 'Try another craft or town, or clear your filters.' : 'Verified artisans\' products will appear here as soon as they list them.'"
        >
          <Button v-if="activeChips.length" variant="outline" @click="clearAll">Clear filters</Button>
        </EmptyState>

        <template v-else>
          <div class="mt-8 grid grid-cols-2 gap-x-5 gap-y-10 md:grid-cols-3">
            <ProductCard v-for="p in products" :key="p.id" :product="p" />
          </div>
          <div v-if="products.length < total" class="mt-12 flex justify-center">
            <Button variant="outline" size="lg" :disabled="loading" @click="loadMore">{{ loading ? 'Loading…' : 'Show more' }}</Button>
          </div>
        </template>
      </section>
    </div>
  </div>
</template>
