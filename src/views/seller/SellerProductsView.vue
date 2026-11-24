<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { SellerProduct } from '@/lib/seller'
import { PencilIcon, PlusIcon, SearchIcon, Trash2Icon } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { peso } from '@/lib/format'
import { deleteProduct, fetchMyProducts, setProductActive } from '@/lib/seller'
import { cn } from '@/lib/utils'
import { useSellerStore } from '@/stores/seller'

const route = useRoute()
const router = useRouter()
const seller = useSellerStore()
const products = ref<SellerProduct[]>([])
const loading = ref(true)
const search = ref('')

type Tab = 'all' | 'live' | 'soldout' | 'hidden'
const tabs: { key: Tab, label: string, match: (p: SellerProduct) => boolean }[] = [
  { key: 'all', label: 'All', match: () => true },
  { key: 'live', label: 'Live', match: p => p.is_active && p.stock > 0 },
  { key: 'soldout', label: 'Sold Out', match: p => p.stock === 0 },
  { key: 'hidden', label: 'Hidden', match: p => !p.is_active },
]
const tab = computed<Tab>(() => (tabs.some(t => t.key === route.query.tab) ? route.query.tab as Tab : 'all'))

async function load() {
  if (!seller.shop) return
  loading.value = true
  try {
    products.value = await fetchMyProducts(seller.shop.id)
  }
  finally {
    loading.value = false
  }
}
watch(() => seller.shop?.id, load, { immediate: true })

const visible = computed(() => {
  const match = tabs.find(t => t.key === tab.value)!.match
  const q = search.value.trim().toLowerCase()
  return products.value.filter(p => match(p) && (!q || p.name.toLowerCase().includes(q)))
})
const count = (key: Tab) => products.value.filter(tabs.find(t => t.key === key)!.match).length
const cover = (p: SellerProduct) => [...p.images].sort((a, b) => a.sort_order - b.sort_order)[0]?.url

async function toggle(p: SellerProduct, value: boolean) {
  const before = p.is_active
  p.is_active = value
  try {
    await setProductActive(p.id, value)
    toast.success(value ? `${p.name} is live.` : `${p.name} is hidden from buyers.`)
  }
  catch (e) {
    p.is_active = before
    toast.error((e as { message?: string }).message ?? 'Could not update')
  }
}

async function remove(p: SellerProduct) {
  if (!await confirmAction({ title: `Delete ${p.name}?`, body: 'This can\'t be undone. To take it down for now, hide it instead.', confirmLabel: 'Delete', destructive: true })) return
  try {
    await deleteProduct(p.id)
    products.value = products.value.filter(x => x.id !== p.id)
    toast.success('Product deleted.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not delete')
  }
}
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <section class="rounded-lg border bg-card">
      <div class="flex flex-wrap items-start justify-between gap-3 px-5 pt-5">
        <div>
          <h1 class="text-lg font-semibold">My Products</h1>
          <p class="text-sm text-muted-foreground">{{ products.length }} {{ products.length === 1 ? 'product' : 'products' }}</p>
        </div>
        <Button as-child class="rounded-full"><RouterLink to="/seller/products/new"><PlusIcon /> Add New Product</RouterLink></Button>
      </div>

      <div class="mt-4 flex flex-wrap items-end justify-between gap-3 border-b px-5">
        <div class="flex gap-6 text-sm" role="tablist">
          <button
            v-for="t in tabs"
            :key="t.key"
            role="tab"
            :aria-selected="tab === t.key"
            :class="cn('-mb-px border-b-2 pb-3 font-medium transition-colors', tab === t.key ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground')"
            @click="router.replace({ query: t.key === 'all' ? {} : { tab: t.key } })"
          >
            {{ t.label }} ({{ count(t.key) }})
          </button>
        </div>
        <label class="mb-2 flex h-10 w-full items-center gap-2 rounded-md border px-3 text-sm sm:w-auto">
          <SearchIcon class="size-4 text-muted-foreground" />
          <input v-model="search" type="search" placeholder="Search product name" aria-label="Search your products" class="w-full bg-transparent outline-none sm:w-44">
        </label>
      </div>

      <!-- Phones: one card per product -->
      <ul class="divide-y md:hidden">
        <li v-if="loading" class="px-5 py-10 text-center text-sm text-muted-foreground">Loading…</li>
        <li v-else-if="!visible.length" class="px-5 py-12 text-center text-sm text-muted-foreground">
          {{ products.length ? 'No products match.' : 'You haven\'t listed anything yet.' }}
          <RouterLink v-if="!products.length" to="/seller/products/new" class="mt-2 block font-medium text-primary">Add your first product</RouterLink>
        </li>
        <li v-for="p in visible" v-else :key="p.id" class="flex gap-3 px-4 py-4">
          <img v-if="cover(p)" :src="cover(p)" alt="" class="size-20 shrink-0 rounded-lg object-cover">
          <div v-else class="size-20 shrink-0 rounded-lg bg-muted" />
          <div class="flex min-w-0 flex-1 flex-col">
            <RouterLink :to="`/seller/products/${p.id}/edit`" class="line-clamp-2 font-medium">{{ p.name }}</RouterLink>
            <p class="text-xs text-muted-foreground">{{ p.category?.name ?? 'No category' }}</p>
            <p class="mt-1 text-sm">
              <span class="font-semibold">{{ peso(p.price) }}</span>
              <span :class="cn('ml-2', p.stock === 0 ? 'font-medium text-destructive' : p.stock <= 5 ? 'font-medium text-primary' : 'text-muted-foreground')">{{ p.stock === 0 ? 'Sold out' : `${p.stock} in stock` }}</span>
            </p>
            <div class="mt-auto flex items-center justify-between pt-2">
              <label class="flex items-center gap-2 text-xs text-muted-foreground">
                <Switch :model-value="p.is_active" :aria-label="`${p.name} live`" @update:model-value="(v: boolean) => toggle(p, v)" />
                {{ p.is_active ? 'Live' : 'Hidden' }}
              </label>
              <div class="flex gap-1">
                <Button as-child variant="ghost" size="icon-sm" :aria-label="`Edit ${p.name}`"><RouterLink :to="`/seller/products/${p.id}/edit`"><PencilIcon /></RouterLink></Button>
                <Button variant="ghost" size="icon-sm" :aria-label="`Delete ${p.name}`" @click="remove(p)"><Trash2Icon /></Button>
              </div>
            </div>
          </div>
        </li>
      </ul>

      <!-- Wider screens: table -->
      <div class="hidden overflow-x-auto md:block">
        <table class="w-full min-w-[720px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Product</th>
              <th class="px-5 py-3 font-medium">Price</th>
              <th class="px-5 py-3 font-medium">Stock</th>
              <th class="px-5 py-3 font-medium">Live</th>
              <th class="px-5 py-3 text-right font-medium">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="5" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!visible.length">
              <td colspan="5" class="px-5 py-12 text-center text-muted-foreground">
                {{ products.length ? 'No products match.' : 'You haven\'t listed anything yet.' }}
                <RouterLink v-if="!products.length" to="/seller/products/new" class="ml-1 font-medium text-primary hover:underline">Add your first product</RouterLink>
              </td>
            </tr>
            <tr v-for="p in visible" v-else :key="p.id" class="hover:bg-secondary/40">
              <td class="px-5 py-3">
                <div class="flex items-center gap-3">
                  <img v-if="cover(p)" :src="cover(p)" alt="" class="size-12 rounded-md object-cover">
                  <div v-else class="size-12 rounded-md bg-muted" />
                  <div class="min-w-0">
                    <p class="truncate font-medium">{{ p.name }}</p>
                    <p class="text-xs text-muted-foreground">{{ p.category?.name ?? 'No category' }}</p>
                  </div>
                </div>
              </td>
              <td class="px-5 py-3 tabular-nums">{{ peso(p.price) }}</td>
              <td :class="cn('px-5 py-3 tabular-nums', p.stock === 0 ? 'font-medium text-destructive' : p.stock <= 5 ? 'font-medium text-primary' : '')">{{ p.stock }}</td>
              <td class="px-5 py-3">
                <Switch :model-value="p.is_active" :aria-label="`${p.name} live`" @update:model-value="(v: boolean) => toggle(p, v)" />
              </td>
              <td class="px-5 py-3">
                <div class="flex justify-end gap-1">
                  <Button as-child variant="ghost" size="icon-sm" :aria-label="`Edit ${p.name}`"><RouterLink :to="`/seller/products/${p.id}/edit`"><PencilIcon /></RouterLink></Button>
                  <Button variant="ghost" size="icon-sm" :aria-label="`Delete ${p.name}`" @click="remove(p)"><Trash2Icon /></Button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
