<script setup lang="ts">
import type { Category, Town } from '@/types/database'
import { ArrowRightIcon, ArrowUpRightIcon, ChevronDownIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import ArchImage from '@/components/ArchImage.vue'
import HablonBand from '@/components/HablonBand.vue'
import HeroShowcase from '@/components/HeroShowcase.vue'
import ProductCard from '@/components/catalog/ProductCard.vue'
import StampBadge from '@/components/StampBadge.vue'
import { Button } from '@/components/ui/button'
import type { CatalogProduct } from '@/lib/catalog'
import { fetchProducts } from '@/lib/catalog'
import { categoryImages, images } from '@/lib/images'
import { isSupabaseConfigured, supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'

type TownStop = Pick<Town, 'name' | 'known_for' | 'lat'>
type CraftCard = Pick<Category, 'name' | 'slug'>

// Shown until Supabase is connected; matches supabase/seed.sql.
const fallbackTowns: TownStop[] = [
  { name: 'Bantayan', known_for: 'Dried fish, shell craft', lat: 11.169 },
  { name: 'Liloan', known_for: 'Rosquillos', lat: 10.3991 },
  { name: 'Mandaue City', known_for: 'Furniture, rattan and wicker', lat: 10.3236 },
  { name: 'Cebu City', known_for: 'Pasalubong, dried mangoes, Sto. Niño crafts', lat: 10.3157 },
  { name: 'Lapu-Lapu City', known_for: 'Guitars and ukuleles, shell craft', lat: 10.3103 },
  { name: 'Talisay City', known_for: 'Lechon', lat: 10.2447 },
  { name: 'Carcar City', known_for: 'Leather shoes, chicharon, ampao', lat: 10.1061 },
  { name: 'Argao', known_for: 'Hablon weaving, torta', lat: 9.8797 },
]
const fallbackCrafts: CraftCard[] = [
  { name: 'Hablon Weaving', slug: 'hablon-weaving' },
  { name: 'Rattan and Wicker', slug: 'rattan-wicker' },
  { name: 'Shell Craft', slug: 'shell-craft' },
  { name: 'Guitars and Instruments', slug: 'guitars-instruments' },
  { name: 'Woodcarving', slug: 'woodcarving' },
  { name: 'Pottery', slug: 'pottery' },
  { name: 'Fashion and Accessories', slug: 'fashion-accessories' },
  { name: 'Pasalubong and Delicacies', slug: 'pasalubong' },
]

// Cebuano word printed down each craft photo, and the filter group it sits in.
const craftMeta: Record<string, { word: string, group: string }> = {
  'hablon-weaving': { word: 'Hablon', group: 'Textiles' },
  'rattan-wicker': { word: 'Uway', group: 'Home' },
  'shell-craft': { word: 'Kinhason', group: 'Gifts' },
  'guitars-instruments': { word: 'Gitara', group: 'Music' },
  'woodcarving': { word: 'Kinulit', group: 'Home' },
  'pottery': { word: 'Kolon', group: 'Home' },
  'fashion-accessories': { word: 'Dayandayan', group: 'Textiles' },
  'pasalubong': { word: 'Pasalubong', group: 'Gifts' },
}

const towns = ref<TownStop[]>(fallbackTowns)
const newArrivals = ref<CatalogProduct[]>([])

interface Spotlight { shop_name: string, slug: string, story: string, photo_url: string | null, craft_since: number | null, town: { name: string } | null }
const featured = ref<Spotlight | null>(null)
const banners = ref<{ id: string, image_url: string, link: string | null }[]>([])
const crafts = ref<CraftCard[]>(fallbackCrafts)

onMounted(async () => {
  if (!isSupabaseConfigured) return
  const [townRes, catRes, arrivals] = await Promise.all([
    supabase.from('towns').select('name, known_for, lat'),
    supabase.from('categories').select('name, slug').order('id'),
    fetchProducts({}, 0, 4).catch(() => ({ products: [] })),
  ])
  newArrivals.value = arrivals.products

  // This week's (or the latest) featured artisan, chosen by the owner.
  const [spot, promo] = await Promise.all([
    supabase
      .from('featured_artisans')
      .select('week_start, artisan:artisans!inner(shop_name, slug, story, photo_url, craft_since, status, town:towns(name))')
      .lte('week_start', new Date().toISOString().slice(0, 10))
      .eq('artisan.status', 'verified')
      .order('week_start', { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase.from('banners').select('id, image_url, link').eq('is_active', true).order('sort_order'),
  ])
  featured.value = (spot.data?.artisan as unknown as Spotlight) ?? null
  banners.value = promo.data ?? []
  if (townRes.data?.length) towns.value = townRes.data
  if (catRes.data?.length) crafts.value = catRes.data
})

const groups = ['All', 'Textiles', 'Home', 'Music', 'Gifts']
const activeGroup = ref('All')
const visibleCrafts = computed(() =>
  activeGroup.value === 'All' ? crafts.value : crafts.value.filter(c => craftMeta[c.slug]?.group === activeGroup.value),
)

// The route runs north to south, like a jeepney signboard down the island.
const route = computed(() => [...towns.value].sort((a, b) => b.lat - a.lat))
const activeStop = ref('Argao')
const activeTown = computed(() => route.value.find(t => t.name === activeStop.value) ?? route.value[0])

const steps = [
  { title: 'Find your maker', body: 'Browse by craft or by town. Every shop opens with the artisan\'s story and hometown.' },
  { title: 'Check out once', body: 'Fill one cart from many shops and pay with Maya or cash on delivery.' },
  { title: 'Each shop ships', body: 'Every artisan packs their own pieces. Track each parcel, then leave a review.' },
]

const faqs = [
  { q: 'How do I pay?', a: 'Pay online through Maya, or choose cash on delivery and pay the courier when your parcel arrives.' },
  { q: 'Why can one order arrive in several parcels?', a: 'Each artisan ships their own pieces, so an order from three shops arrives in up to three parcels. You can track each one.' },
  { q: 'What does the Verified Cebuano Artisan stamp mean?', a: 'We review every seller\'s story, town and sample work before their shop goes live. Only verified shops appear on CraftCebu.' },
  { q: 'How much is shipping?', a: 'A flat fee per shop in your order, shown at checkout before you pay.' },
  { q: 'Can I sell my crafts here?', a: 'Yes, if you make your craft in Cebu. Create an account, apply with your story and sample photos, and we\'ll review it.' },
]
const openFaq = ref<number | null>(0)
</script>

<template>
  <HeroShowcase />

  <HablonBand />

  <section v-if="banners.length" class="mx-auto mt-10 flex max-w-6xl snap-x gap-4 overflow-x-auto px-4 [scrollbar-width:none]" aria-label="Promotions">
    <component :is="b.link ? 'RouterLink' : 'div'" v-for="b in banners" :key="b.id" :to="b.link ?? undefined" class="w-full shrink-0 snap-start overflow-hidden rounded-2xl sm:w-[85%] lg:w-[70%]">
      <img :src="b.image_url" alt="" class="aspect-[16/5] w-full object-cover">
    </component>
  </section>

  <!-- Crafts -->
  <section id="crafts" class="mx-auto max-w-6xl px-4 py-20">
    <div class="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
      <div>
        <p class="caps text-primary">Mga Craft</p>
        <h2 class="mt-3 font-display text-4xl font-medium sm:text-5xl">Pick a craft</h2>
      </div>
      <div class="flex flex-wrap gap-2" role="group" aria-label="Filter crafts">
        <button
          v-for="g in groups"
          :key="g"
          :aria-pressed="activeGroup === g"
          :class="cn('h-10 rounded-full border px-4 text-sm font-medium transition-colors', activeGroup === g ? 'border-foreground bg-foreground text-background' : 'hover:border-foreground')"
          @click="activeGroup = g"
        >
          {{ g }}
        </button>
      </div>
    </div>

    <div class="mt-10 grid grid-cols-2 gap-x-5 gap-y-8 md:grid-cols-4">
      <article v-for="c in visibleCrafts" :key="c.slug" class="group relative">
        <div class="relative overflow-hidden rounded-xl bg-muted">
          <img :src="categoryImages[c.slug] ?? images.wovenTexture" :alt="c.name" loading="lazy" class="aspect-[3/4] w-full object-cover transition-transform duration-500 group-hover:scale-[1.04]">
          <span class="side-label absolute top-3 right-3 bg-black/25 text-white backdrop-blur-sm">{{ craftMeta[c.slug]?.word ?? c.name }}</span>
        </div>
        <div class="mt-3 flex items-start justify-between gap-2">
          <div>
            <h3 class="font-medium"><RouterLink :to="{ path: '/shop', query: { category: c.slug } }" class="after:absolute after:inset-0">{{ c.name }}</RouterLink></h3>
            <p class="text-sm text-muted-foreground">{{ craftMeta[c.slug]?.group ?? 'Craft' }}</p>
          </div>
          <span class="grid size-8 shrink-0 place-items-center rounded-full border transition-colors group-hover:border-primary group-hover:bg-primary group-hover:text-primary-foreground" aria-hidden="true">
            <ArrowUpRightIcon class="size-4" />
          </span>
        </div>
      </article>
    </div>
  </section>

  <!-- New arrivals (only once artisans have listed products) -->
  <section v-if="newArrivals.length" class="mx-auto max-w-6xl px-4 pb-20">
    <div class="flex items-end justify-between gap-4">
      <div>
        <p class="caps text-primary">Bag-o · Just listed</p>
        <h2 class="mt-3 font-display text-4xl font-medium sm:text-5xl">New from the makers</h2>
      </div>
      <RouterLink to="/shop" class="flex shrink-0 items-center gap-2 text-sm font-medium hover:text-primary">See all <ArrowRightIcon class="size-4" /></RouterLink>
    </div>
    <div class="mt-10 grid grid-cols-2 gap-x-5 gap-y-10 md:grid-cols-4">
      <ProductCard v-for="p in newArrivals" :key="p.id" :product="p" />
    </div>
  </section>

  <!-- Towns: a north-to-south route of stops -->
  <section id="towns" class="clay-panel relative overflow-hidden py-20">
    <p class="pointer-events-none absolute -bottom-10 left-1/2 -translate-x-1/2 font-display text-[11rem] leading-none font-semibold whitespace-nowrap opacity-[0.06] select-none sm:text-[18rem]" aria-hidden="true">
      SUGBO
    </p>
    <div class="relative mx-auto max-w-6xl px-4">
      <p class="caps text-mango">Sakay na · All aboard</p>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <h2 class="mt-3 max-w-xl font-display text-4xl font-medium sm:text-5xl">Ride the island, town by town</h2>
        <RouterLink to="/origins" class="flex items-center gap-2 text-sm font-medium hover:text-mango">Open the map <ArrowRightIcon class="size-4" /></RouterLink>
      </div>

      <ol class="mt-14 flex gap-0 overflow-x-auto pb-4 [scrollbar-width:none]" aria-label="Towns from north to south">
        <li v-for="(t, i) in route" :key="t.name" class="relative min-w-32 flex-1">
          <span v-if="i < route.length - 1" class="absolute top-[11px] left-1/2 h-0.5 w-full bg-white/25" aria-hidden="true" />
          <button class="relative flex w-full flex-col items-center gap-3 text-center" :aria-pressed="activeStop === t.name" @click="activeStop = t.name">
            <span :class="cn('grid size-6 place-items-center rounded-full border-2 transition-colors', activeStop === t.name ? 'border-mango bg-mango' : 'border-white/60 bg-clay-deep')">
              <span v-if="activeStop === t.name" class="size-2 rounded-full bg-ink" />
            </span>
            <span :class="cn('text-sm transition-opacity', activeStop === t.name ? 'font-semibold' : 'opacity-70')">{{ t.name }}</span>
          </button>
        </li>
      </ol>

      <div v-if="activeTown" class="mt-8 grid gap-6 rounded-2xl bg-white/8 p-6 backdrop-blur-sm sm:grid-cols-[auto_1fr_auto] sm:items-center sm:p-8">
        <span class="w-fit rounded-md bg-mango px-3 py-1.5 font-display text-sm font-semibold text-ink">{{ activeTown.name }}</span>
        <div>
          <p class="text-xs opacity-70">Known for</p>
          <p class="mt-1 font-display text-2xl">{{ activeTown.known_for }}</p>
        </div>
        <RouterLink :to="{ path: '/shop', query: { town: activeTown.name } }" class="flex items-center gap-2 text-sm font-medium hover:text-mango">Shop {{ activeTown.name }} <ArrowRightIcon class="size-4" /></RouterLink>
      </div>
    </div>
  </section>

  <!-- Artisan of the week -->
  <section v-if="featured" class="mx-auto max-w-6xl px-4 pt-24">
    <div class="grid items-center gap-10 overflow-hidden rounded-3xl border bg-card p-6 sm:p-10 md:grid-cols-[auto_1fr]">
      <div class="relative mx-auto">
        <img v-if="featured.photo_url" :src="featured.photo_url" :alt="featured.shop_name" class="h-72 w-56 rounded-t-[999px] rounded-b-xl object-cover">
        <div v-else class="grid h-72 w-56 place-items-center rounded-t-[999px] rounded-b-xl bg-primary font-display text-7xl text-primary-foreground">{{ featured.shop_name[0] }}</div>
        <StampBadge text="ARTISAN OF THE WEEK · CRAFTCEBU ·" class="absolute -right-8 -bottom-6 size-24" />
      </div>
      <div>
        <p class="caps text-primary">Artisan of the week</p>
        <h2 class="mt-3 font-display text-4xl font-medium sm:text-5xl">{{ featured.shop_name }}</h2>
        <p class="mt-2 text-sm text-muted-foreground">
          <span v-if="featured.town">{{ featured.town.name }}, Cebu</span><span v-if="featured.craft_since"> · in the craft since {{ featured.craft_since }}</span>
        </p>
        <p class="mt-5 line-clamp-4 max-w-xl font-display text-lg leading-relaxed whitespace-pre-line">{{ featured.story }}</p>
        <Button as-child class="mt-6"><RouterLink :to="`/artisans/${featured.slug}`">Visit the shop <ArrowRightIcon /></RouterLink></Button>
      </div>
    </div>
  </section>

  <!-- Makers -->
  <section id="makers" class="mx-auto grid max-w-6xl items-center gap-14 px-4 py-24 md:grid-cols-2">
    <div class="relative mx-auto w-full max-w-sm">
      <ArchImage :src="images.weavingHands" alt="An artisan's hands weaving dried straw" class="aspect-[4/5] w-full" />
      <div class="absolute -right-4 -bottom-4 -z-10 h-full w-full rounded-t-[999px] rounded-b-lg bg-mango/50" aria-hidden="true" />
    </div>
    <div>
      <p class="caps text-primary">Ang mga Artisan</p>
      <h2 class="mt-3 font-display text-4xl font-medium sm:text-5xl">Every piece has a name behind it</h2>
      <blockquote class="mt-8 border-l-2 border-primary pl-5 font-display text-xl leading-relaxed italic">
        A CraftCebu shop opens with the maker, not the product: who they are, where they work, and how long they've kept the craft alive.
      </blockquote>
      <ul class="mt-8 grid gap-4 text-sm">
        <li class="flex gap-3"><span class="mt-1.5 size-2 shrink-0 rounded-full bg-primary" /> Artisan story, hometown and years in the craft on every shop page</li>
        <li class="flex gap-3"><span class="mt-1.5 size-2 shrink-0 rounded-full bg-mango" /> The maker's name and town on every product</li>
        <li class="flex gap-3"><span class="mt-1.5 size-2 shrink-0 rounded-full bg-indigo" /> A Verified Cebuano Artisan stamp after we review each seller</li>
      </ul>
    </div>
  </section>

  <!-- How it works -->
  <section id="how" class="border-y bg-secondary py-20">
    <div class="mx-auto max-w-6xl px-4">
      <h2 class="font-display text-4xl font-medium sm:text-5xl">How CraftCebu works</h2>
      <div class="mt-12 grid gap-5 md:grid-cols-3">
        <article v-for="(s, i) in steps" :key="s.title" class="rounded-2xl border bg-card p-7">
          <span class="font-display text-6xl text-primary italic">{{ i + 1 }}</span>
          <h3 class="mt-6 text-lg font-semibold">{{ s.title }}</h3>
          <p class="mt-2 text-sm leading-relaxed text-muted-foreground">{{ s.body }}</p>
        </article>
      </div>
    </div>
  </section>

  <!-- Seller call to action -->
  <section class="mx-auto max-w-6xl px-4 py-20">
    <div class="relative grid items-center gap-8 overflow-hidden rounded-3xl bg-primary px-8 py-14 text-primary-foreground sm:px-14 md:grid-cols-[1fr_auto]">
      <div>
        <p class="caps opacity-80">Para sa mga artisan</p>
        <h2 class="mt-3 font-display text-4xl font-medium sm:text-5xl">Ikaw ba usa ka artisan?</h2>
        <p class="mt-3 max-w-lg opacity-85">Are you a Cebuano maker? Open a verified shop, tell your story and reach buyers across the Philippines.</p>
        <Button size="lg" class="mt-8 bg-background text-foreground hover:bg-background/90" as-child>
          <RouterLink to="/sell">Apply to sell <ArrowRightIcon /></RouterLink>
        </Button>
      </div>
      <StampBadge class="size-36 justify-self-center" />
    </div>
  </section>

  <!-- FAQ -->
  <section id="faq" class="mx-auto grid max-w-6xl gap-10 px-4 pb-24 md:grid-cols-[1fr_1.6fr]">
    <div class="md:sticky md:top-24 md:self-start">
      <p class="caps text-primary">Pangutana</p>
      <h2 class="mt-3 font-display text-4xl font-medium sm:text-5xl">Questions, answered</h2>
      <p class="mt-4 text-sm text-muted-foreground">Still curious? Email <a href="mailto:hello@craftcebu.test" class="text-foreground underline underline-offset-4">hello@craftcebu.test</a>.</p>
    </div>
    <div class="divide-y border-y">
      <div v-for="(f, i) in faqs" :key="f.q">
        <button class="flex w-full items-center justify-between gap-6 py-5 text-left font-medium" :aria-expanded="openFaq === i" @click="openFaq = openFaq === i ? null : i">
          {{ f.q }}
          <ChevronDownIcon :class="cn('size-5 shrink-0 text-muted-foreground transition-transform', openFaq === i && 'rotate-180 text-primary')" />
        </button>
        <p v-if="openFaq === i" class="max-w-xl pb-6 text-sm leading-relaxed text-muted-foreground">{{ f.a }}</p>
      </div>
    </div>
  </section>
</template>
