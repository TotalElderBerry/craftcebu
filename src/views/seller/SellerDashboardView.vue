<script setup lang="ts">
import type { SellerProduct } from '@/lib/seller'
import { ExternalLinkIcon, PlusIcon } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import { Button } from '@/components/ui/button'
import { peso } from '@/lib/format'
import { fetchShopOrders } from '@/lib/orders'
import { fetchMyProducts } from '@/lib/seller'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'
import { useSellerStore } from '@/stores/seller'

const auth = useAuthStore()
const seller = useSellerStore()
const products = ref<SellerProduct[]>([])
const loaded = ref(false)
const toShip = ref<number | null>(null)

watch(() => seller.shop?.id, async (id) => {
  if (!id) return
  const [list, orders] = await Promise.all([fetchMyProducts(id), fetchShopOrders(id)])
  products.value = list
  toShip.value = orders.filter(o => o.status === 'pending' && (o.order.payment_method === 'cod' || o.order.payment_status === 'paid')).length
  loaded.value = true
}, { immediate: true })

const todos = computed(() => [
  { label: 'To Ship', value: toShip.value, to: '/seller/orders' },
  { label: 'Sold Out', value: loaded.value ? products.value.filter(p => p.stock === 0).length : null, to: '/seller/products?tab=soldout', hint: undefined },
  { label: 'Low Stock (≤5)', value: loaded.value ? products.value.filter(p => p.stock > 0 && p.stock <= 5).length : null, to: '/seller/products?tab=live' },
  { label: 'Hidden', value: loaded.value ? products.value.filter(p => !p.is_active).length : null, to: '/seller/products?tab=hidden' },
])

const live = computed(() => products.value.filter(p => p.is_active))
const stockValue = computed(() => live.value.reduce((s, p) => s + p.price * p.stock, 0))
</script>

<template>
  <div class="mx-auto grid max-w-7xl gap-4 xl:grid-cols-[1fr_320px]">
    <div class="grid min-w-0 content-start gap-4">
      <section class="rounded-lg border bg-card p-5">
        <h1 class="text-lg font-semibold">To Do List</h1>
        <p class="text-sm text-muted-foreground">Things you need to deal with</p>
        <div class="mt-4 grid grid-cols-2 gap-px overflow-hidden rounded-md border bg-border sm:grid-cols-4">
          <component
            :is="t.to ? 'RouterLink' : 'div'"
            v-for="t in todos"
            :key="t.label"
            :to="t.to"
            :title="t.hint"
            class="flex flex-col items-center gap-1 bg-card px-2 py-4 text-center transition-colors hover:bg-secondary/50"
          >
            <span :class="cn('text-2xl font-semibold tabular-nums', t.value ? 'text-primary' : '')">{{ t.value ?? '–' }}</span>
            <span class="text-xs text-muted-foreground">{{ t.label }}</span>
          </component>
        </div>
      </section>

      <section class="rounded-lg border bg-card p-5">
        <div class="flex items-center justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">Recently added</h2>
            <p class="text-sm text-muted-foreground">{{ live.length }} live · {{ products.length - live.length }} hidden</p>
          </div>
          <Button as-child size="sm" class="rounded-full"><RouterLink to="/seller/products/new"><PlusIcon /> Add product</RouterLink></Button>
        </div>
        <div v-if="loaded && !products.length" class="mt-6 rounded-lg border border-dashed p-10 text-center">
          <p class="font-display text-xl">List your first piece</p>
          <p class="mt-1 text-sm text-muted-foreground">Add photos, a price and how many you have. It goes live right away.</p>
          <Button as-child class="mt-4"><RouterLink to="/seller/products/new"><PlusIcon /> Add product</RouterLink></Button>
        </div>
        <ul v-else class="mt-4 divide-y">
          <li v-for="p in products.slice(0, 5)" :key="p.id" class="flex items-center gap-3 py-3">
            <img v-if="p.images[0]" :src="[...p.images].sort((a, b) => a.sort_order - b.sort_order)[0]!.url" alt="" class="size-12 rounded-md object-cover">
            <div v-else class="size-12 rounded-md bg-muted" />
            <div class="min-w-0 flex-1">
              <RouterLink :to="`/seller/products/${p.id}/edit`" class="block truncate font-medium hover:text-primary">{{ p.name }}</RouterLink>
              <p class="text-xs text-muted-foreground">{{ peso(p.price) }} · {{ p.stock }} in stock</p>
            </div>
            <span :class="cn('rounded-full px-2.5 py-0.5 text-xs font-medium', p.is_active ? 'bg-[oklch(0.93_0.06_150)] text-[oklch(0.4_0.1_150)]' : 'bg-secondary text-muted-foreground')">{{ p.is_active ? 'Live' : 'Hidden' }}</span>
          </li>
        </ul>
      </section>
    </div>

    <div class="grid content-start gap-4">
      <section v-if="seller.shop" class="rounded-lg border bg-card p-5">
        <div class="flex items-center gap-3">
          <img v-if="seller.shop.photo_url" :src="seller.shop.photo_url" alt="" class="size-14 rounded-full object-cover">
          <div v-else class="grid size-14 place-items-center rounded-full bg-primary font-display text-2xl text-primary-foreground">{{ seller.shop.shop_name[0] }}</div>
          <div class="min-w-0">
            <p class="text-sm text-muted-foreground">Maayong adlaw, {{ auth.profile?.full_name?.split(' ')[0] || 'artisan' }}</p>
            <p class="truncate font-display text-xl font-medium">{{ seller.shop.shop_name }}</p>
          </div>
        </div>
        <VerifiedBadge class="mt-4" />
        <dl class="mt-4 grid grid-cols-2 gap-3 text-sm">
          <div class="rounded-md bg-secondary p-3">
            <dt class="text-xs text-muted-foreground">Live products</dt>
            <dd class="mt-0.5 font-semibold">{{ live.length }}</dd>
          </div>
          <div class="rounded-md bg-secondary p-3">
            <dt class="text-xs text-muted-foreground">Stock value</dt>
            <dd class="mt-0.5 font-semibold">{{ peso(stockValue) }}</dd>
          </div>
        </dl>
        <div class="mt-4 flex flex-col gap-2">
          <Button as-child variant="outline" size="sm" class="rounded-full"><RouterLink :to="`/artisans/${seller.shop.slug}`"><ExternalLinkIcon /> View my shop</RouterLink></Button>
          <Button as-child variant="ghost" size="sm" class="rounded-full"><RouterLink to="/seller/shop">Edit shop profile</RouterLink></Button>
        </div>
      </section>

      <section class="rounded-lg border bg-card p-5 text-sm">
        <h2 class="font-semibold">Tips for selling well</h2>
        <ul class="mt-3 grid gap-2 text-muted-foreground">
          <li>Use 3 or more photos in daylight, with the cover showing the whole piece.</li>
          <li>Name the materials and size in the description.</li>
          <li>Keep stock accurate so buyers never order something you've run out of.</li>
        </ul>
      </section>
    </div>
  </div>
</template>
