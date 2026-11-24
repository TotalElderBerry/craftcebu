<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { AdminArtisan } from '@/lib/admin'
import { ExternalLinkIcon, SearchIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import { Button } from '@/components/ui/button'
import { fetchAllArtisans, setArtisanStatus } from '@/lib/admin'
import { cn } from '@/lib/utils'

const rows = ref<AdminArtisan[]>([])
const loading = ref(true)
const tab = ref<'verified' | 'suspended'>('verified')
const search = ref('')
const busy = ref<string | null>(null)

async function load() {
  loading.value = true
  try {
    rows.value = await fetchAllArtisans()
  }
  finally {
    loading.value = false
  }
}
onMounted(load)

const visible = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rows.value.filter(a => a.status === tab.value && (!q || a.shop_name.toLowerCase().includes(q) || a.owner?.full_name.toLowerCase().includes(q) || a.town?.name.toLowerCase().includes(q)))
})
const count = (s: string) => rows.value.filter(a => a.status === s).length

async function toggle(a: AdminArtisan) {
  const suspend = a.status === 'verified'
  if (suspend && !await confirmAction({ title: `Suspend ${a.shop_name}?`, body: 'Their shop and products disappear from CraftCebu until you reactivate it.', confirmLabel: 'Suspend', destructive: true })) return
  busy.value = a.id
  try {
    await setArtisanStatus(a.id, suspend ? 'suspended' : 'verified')
    a.status = suspend ? 'suspended' : 'verified'
    toast.success(suspend ? `${a.shop_name} is suspended.` : `${a.shop_name} is live again.`)
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update the shop')
  }
  finally {
    busy.value = null
  }
}
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <AdminCard title="All Artisans" subtitle="Verified shops on CraftCebu. Suspending hides a shop and its products.">
      <template #actions>
        <label class="flex h-10 items-center gap-2 rounded-md border px-3 text-sm">
          <SearchIcon class="size-4 text-muted-foreground" />
          <input v-model="search" type="search" placeholder="Shop, maker or town" aria-label="Search artisans" class="w-full min-w-0 bg-transparent outline-none sm:w-44">
        </label>
      </template>
      <template #tabs>
        <TabButton :active="tab === 'verified'" :count="count('verified')" @select="tab = 'verified'">Active</TabButton>
        <TabButton :active="tab === 'suspended'" :count="count('suspended')" @select="tab = 'suspended'">Suspended</TabButton>
      </template>
      <div class="overflow-x-auto">
        <table class="w-full min-w-[760px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Shop</th>
              <th class="px-5 py-3 font-medium">Maker</th>
              <th class="px-5 py-3 font-medium">Town</th>
              <th class="px-5 py-3 font-medium">Products</th>
              <th class="px-5 py-3 font-medium">Verified</th>
              <th class="px-5 py-3 text-right font-medium">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="6" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!visible.length"><td colspan="6" class="px-5 py-12 text-center text-muted-foreground">No shops here.</td></tr>
            <tr v-for="a in visible" v-else :key="a.id" class="hover:bg-secondary/40">
              <td class="px-5 py-3">
                <div class="flex items-center gap-3">
                  <img v-if="a.photo_url" :src="a.photo_url" alt="" class="size-10 rounded-full object-cover">
                  <div v-else class="grid size-10 place-items-center rounded-full bg-primary font-display text-primary-foreground">{{ a.shop_name[0] }}</div>
                  <div>
                    <p class="font-medium">{{ a.shop_name }}</p>
                    <RouterLink v-if="a.status === 'verified'" :to="`/artisans/${a.slug}`" class="flex items-center gap-1 text-xs text-muted-foreground hover:text-primary">View shop <ExternalLinkIcon class="size-3" /></RouterLink>
                  </div>
                </div>
              </td>
              <td class="px-5 py-3">
                <p>{{ a.owner?.full_name || '—' }}</p>
                <p class="text-xs text-muted-foreground">{{ a.owner?.email }}</p>
              </td>
              <td class="px-5 py-3">{{ a.town?.name ?? '—' }}</td>
              <td class="px-5 py-3 tabular-nums">{{ a.products[0]?.count ?? 0 }}</td>
              <td class="px-5 py-3 text-muted-foreground">{{ a.verified_at ? new Date(a.verified_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) : '—' }}</td>
              <td class="px-5 py-3 text-right">
                <Button size="sm" variant="outline" :class="cn('rounded-full', a.status === 'verified' && 'text-destructive')" :disabled="busy === a.id" @click="toggle(a)">
                  {{ a.status === 'verified' ? 'Suspend' : 'Reactivate' }}
                </Button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </AdminCard>
  </div>
</template>
