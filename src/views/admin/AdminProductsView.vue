<script setup lang="ts">
import type { AdminProduct } from '@/lib/admin'
import { ExternalLinkIcon, SearchIcon, StarIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import { Button } from '@/components/ui/button'
import { fetchAllProducts, setProductFlags } from '@/lib/admin'
import { peso } from '@/lib/format'
import { cn } from '@/lib/utils'

const route = useRoute()
const router = useRouter()
const rows = ref<AdminProduct[]>([])
const loading = ref(true)
const search = ref('')
const busy = ref<string | null>(null)

type Tab = 'all' | 'live' | 'hidden' | 'featured'
const tabs: { key: Tab, label: string, match: (p: AdminProduct) => boolean }[] = [
  { key: 'all', label: 'All', match: () => true },
  { key: 'live', label: 'Live', match: p => p.is_active && p.artisan?.status === 'verified' },
  { key: 'hidden', label: 'Hidden', match: p => !p.is_active },
  { key: 'featured', label: 'Featured', match: p => p.is_featured },
]
const tab = computed<Tab>(() => (tabs.some(t => t.key === route.query.tab) ? route.query.tab as Tab : 'all'))

onMounted(async () => {
  try {
    rows.value = await fetchAllProducts()
  }
  finally {
    loading.value = false
  }
})

const visible = computed(() => {
  const m = tabs.find(t => t.key === tab.value)!.match
  const q = search.value.trim().toLowerCase()
  return rows.value.filter(p => m(p) && (!q || p.name.toLowerCase().includes(q) || p.artisan?.shop_name.toLowerCase().includes(q)))
})
const count = (key: Tab) => rows.value.filter(tabs.find(t => t.key === key)!.match).length
const cover = (p: AdminProduct) => [...p.images].sort((a, b) => a.sort_order - b.sort_order)[0]?.url

async function update(p: AdminProduct, flags: Partial<Pick<AdminProduct, 'is_active' | 'is_featured'>>, message: string) {
  busy.value = p.id
  try {
    await setProductFlags(p.id, flags)
    Object.assign(p, flags)
    toast.success(message)
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update the product')
  }
  finally {
    busy.value = null
  }
}
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <AdminCard title="All Products" subtitle="Hide listings that break the rules; feature the ones you want buyers to see first.">
      <template #actions>
        <label class="flex h-10 items-center gap-2 rounded-md border px-3 text-sm">
          <SearchIcon class="size-4 text-muted-foreground" />
          <input v-model="search" type="search" placeholder="Product or shop" aria-label="Search products" class="w-full min-w-0 bg-transparent outline-none sm:w-44">
        </label>
      </template>
      <template #tabs>
        <TabButton v-for="t in tabs" :key="t.key" :active="tab === t.key" :count="count(t.key)" @select="router.replace({ query: t.key === 'all' ? {} : { tab: t.key } })">{{ t.label }}</TabButton>
      </template>
      <div class="overflow-x-auto">
        <table class="w-full min-w-[820px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Product</th>
              <th class="px-5 py-3 font-medium">Shop</th>
              <th class="px-5 py-3 font-medium">Price</th>
              <th class="px-5 py-3 font-medium">Stock</th>
              <th class="px-5 py-3 font-medium">Status</th>
              <th class="px-5 py-3 text-right font-medium">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="6" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!visible.length"><td colspan="6" class="px-5 py-12 text-center text-muted-foreground">No products here.</td></tr>
            <tr v-for="p in visible" v-else :key="p.id" class="hover:bg-secondary/40">
              <td class="px-5 py-3">
                <div class="flex items-center gap-3">
                  <img v-if="cover(p)" :src="cover(p)" alt="" class="size-11 rounded-md object-cover">
                  <div v-else class="size-11 rounded-md bg-muted" />
                  <div class="min-w-0">
                    <p class="flex items-center gap-1 font-medium">{{ p.name }} <StarIcon v-if="p.is_featured" class="size-3.5 fill-mango text-mango" aria-label="Featured" /></p>
                    <p class="text-xs text-muted-foreground">{{ p.category?.name ?? 'No category' }}</p>
                  </div>
                </div>
              </td>
              <td class="px-5 py-3">{{ p.artisan?.shop_name ?? '—' }}<span v-if="p.artisan?.status === 'suspended'" class="ml-1 text-xs text-destructive">(suspended)</span></td>
              <td class="px-5 py-3 tabular-nums">{{ peso(p.price) }}</td>
              <td :class="cn('px-5 py-3 tabular-nums', p.stock === 0 && 'text-destructive')">{{ p.stock }}</td>
              <td class="px-5 py-3"><span :class="p.is_active ? 'text-[oklch(0.45_0.1_150)]' : 'text-muted-foreground'">{{ p.is_active ? 'Live' : 'Hidden' }}</span></td>
              <td class="px-5 py-3">
                <div class="flex justify-end gap-1">
                  <Button as-child variant="ghost" size="icon-sm" :aria-label="`Open ${p.name}`"><RouterLink :to="`/product/${p.slug}`"><ExternalLinkIcon /></RouterLink></Button>
                  <Button size="sm" variant="outline" class="rounded-full" :disabled="busy === p.id" @click="update(p, { is_featured: !p.is_featured }, p.is_featured ? 'Removed from featured.' : 'Featured.')">
                    {{ p.is_featured ? 'Unfeature' : 'Feature' }}
                  </Button>
                  <Button size="sm" variant="outline" :class="cn('rounded-full', p.is_active && 'text-destructive')" :disabled="busy === p.id" @click="update(p, { is_active: !p.is_active }, p.is_active ? 'Hidden from buyers.' : 'Visible to buyers again.')">
                    {{ p.is_active ? 'Hide' : 'Unhide' }}
                  </Button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </AdminCard>
  </div>
</template>
