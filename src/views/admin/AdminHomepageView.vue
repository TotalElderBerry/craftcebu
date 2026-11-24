<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { AdminArtisan, Banner } from '@/lib/admin'
import { BadgeCheckIcon, Trash2Icon } from '@lucide/vue'
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import ImageUploader from '@/components/seller/ImageUploader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { deleteBanner, fetchAllArtisans, fetchBanners, fetchFeaturedHistory, saveBanner, setFeaturedArtisan, weekStart } from '@/lib/admin'

const route = useRoute()
const router = useRouter()
const tab = ref<'featured' | 'banners'>(route.query.tab === 'banners' ? 'banners' : 'featured')
const artisans = ref<AdminArtisan[]>([])
const history = ref<Awaited<ReturnType<typeof fetchFeaturedHistory>>>([])
const banners = ref<Banner[]>([])
const pick = ref('')
const busy = ref(false)
const thisWeek = weekStart()

async function load() {
  const [a, h, b] = await Promise.all([fetchAllArtisans(), fetchFeaturedHistory(), fetchBanners()])
  artisans.value = a.filter(x => x.status === 'verified')
  history.value = h
  banners.value = b
  pick.value = h.find(x => x.week_start === thisWeek)?.artisan?.id ?? ''
}
onMounted(load)

function selectTab(t: 'featured' | 'banners') {
  tab.value = t
  router.replace({ query: t === 'banners' ? { tab: 'banners' } : {} })
}

const current = computed(() => history.value.find(x => x.week_start === thisWeek)?.artisan ?? null)

async function feature() {
  if (!pick.value) return
  busy.value = true
  try {
    await setFeaturedArtisan(pick.value)
    toast.success('Featured artisan of the week updated.')
    await load()
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save')
  }
  finally {
    busy.value = false
  }
}

const draft = reactive({ images: [] as string[], link: '' })

async function addBanner() {
  if (!draft.images[0]) return
  busy.value = true
  try {
    await saveBanner({ image_url: draft.images[0], link: draft.link.trim() || null, sort_order: banners.value.length, is_active: true })
    Object.assign(draft, { images: [], link: '' })
    toast.success('Banner added to the homepage.')
    await load()
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not add the banner')
  }
  finally {
    busy.value = false
  }
}

async function toggleBanner(b: Banner, active: boolean) {
  await saveBanner({ ...b, is_active: active })
  b.is_active = active
}

async function removeBanner(b: Banner) {
  if (!await confirmAction({ title: 'Delete this banner?', body: 'It\'s removed from the homepage right away.', confirmLabel: 'Delete', destructive: true })) return
  await deleteBanner(b.id)
  banners.value = banners.value.filter(x => x.id !== b.id)
}

const weekLabel = (d: string) => `Week of ${new Date(`${d}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })}`
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <AdminCard title="Homepage" subtitle="Choose what buyers see first on the CraftCebu homepage.">
      <template #tabs>
        <TabButton :active="tab === 'featured'" @select="selectTab('featured')">Featured Artisan</TabButton>
        <TabButton :active="tab === 'banners'" :count="banners.length" @select="selectTab('banners')">Banners</TabButton>
      </template>

      <div v-if="tab === 'featured'" class="grid gap-6 p-5 md:grid-cols-[1fr_1fr]">
        <div>
          <h2 class="font-semibold">{{ weekLabel(thisWeek) }}</h2>
          <p class="text-sm text-muted-foreground">The featured artisan gets a spotlight section on the homepage all week.</p>
          <div class="mt-4 flex gap-2">
            <select v-model="pick" aria-label="Featured artisan" class="h-10 flex-1 rounded-md border bg-card px-3 text-sm">
              <option value="" disabled>Choose a verified shop</option>
              <option v-for="a in artisans" :key="a.id" :value="a.id">{{ a.shop_name }}{{ a.town ? ` · ${a.town.name}` : '' }}</option>
            </select>
            <Button :disabled="busy || !pick || pick === current?.id" @click="feature">Feature</Button>
          </div>
          <div v-if="current" class="mt-5 flex items-center gap-3 rounded-lg bg-secondary p-4">
            <img v-if="current.photo_url" :src="current.photo_url" alt="" class="size-12 rounded-full object-cover">
            <div>
              <p class="flex items-center gap-1 text-sm font-semibold"><BadgeCheckIcon class="size-4 text-primary" /> {{ current.shop_name }}</p>
              <p class="text-xs text-muted-foreground">On the homepage this week</p>
            </div>
          </div>
        </div>
        <div>
          <h2 class="font-semibold">Past weeks</h2>
          <ul class="mt-3 divide-y text-sm">
            <li v-if="!history.length" class="py-3 text-muted-foreground">No featured artisans yet.</li>
            <li v-for="h in history" :key="h.id" class="flex justify-between gap-3 py-2.5">
              <span>{{ h.artisan?.shop_name ?? '(removed shop)' }}</span>
              <span class="text-muted-foreground">{{ weekLabel(h.week_start) }}</span>
            </li>
          </ul>
        </div>
      </div>

      <div v-else class="grid gap-6 p-5">
        <form class="grid gap-4 rounded-lg border border-dashed p-4" @submit.prevent="addBanner">
          <div class="grid gap-2">
            <Label>New banner image <span class="font-normal text-muted-foreground">(wide, about 1600 × 500)</span></Label>
            <ImageUploader v-model="draft.images" bucket="banners" :max="1" />
          </div>
          <div class="grid gap-2">
            <Label for="banner-link">Link <span class="font-normal text-muted-foreground">(optional, e.g. /shop?category=hablon-weaving)</span></Label>
            <Input id="banner-link" v-model="draft.link" maxlength="300" />
          </div>
          <Button type="submit" class="justify-self-start" :disabled="busy || !draft.images.length">Add banner</Button>
        </form>
        <p v-if="!banners.length" class="text-sm text-muted-foreground">No banners yet. Active banners show as a strip under the homepage hero.</p>
        <ul class="grid gap-3">
          <li v-for="b in banners" :key="b.id" class="flex flex-wrap items-center gap-4 rounded-lg border p-3">
            <img :src="b.image_url" alt="" class="h-16 w-48 rounded-md object-cover">
            <span class="min-w-0 flex-1 truncate text-sm text-muted-foreground">{{ b.link || 'No link' }}</span>
            <label class="flex items-center gap-2 text-sm">Live <Switch :model-value="b.is_active" @update:model-value="(v: boolean) => toggleBanner(b, v)" /></label>
            <Button variant="ghost" size="icon-sm" aria-label="Delete banner" @click="removeBanner(b)"><Trash2Icon /></Button>
          </li>
        </ul>
      </div>
    </AdminCard>
  </div>
</template>
