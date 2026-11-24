<script setup lang="ts">
import type { OrderRow, PurchaseStage, ShopOrderRow } from '@/lib/orders'
import { StoreIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/catalog/EmptyState.vue'
import { Button } from '@/components/ui/button'
import { peso } from '@/lib/format'
import { fetchMyOrders, shortId, stageLabels, stageOf } from '@/lib/orders'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const orders = ref<OrderRow[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    orders.value = await fetchMyOrders(auth.user!.id)
  }
  finally {
    loading.value = false
  }
})

// Like Shopee's My Purchases, each shop's parcel is listed on its own.
const parcels = computed(() => orders.value.flatMap(order => order.shops.map(shop => ({ order, shop, stage: stageOf(order, shop) }))))

type Tab = 'all' | PurchaseStage
const tabs: Tab[] = ['all', 'to-pay', 'to-ship', 'to-receive', 'completed', 'cancelled']
const tab = computed<Tab>(() => (tabs.includes(route.query.tab as Tab) ? route.query.tab as Tab : 'all'))
const visible = computed(() => (tab.value === 'all' ? parcels.value : parcels.value.filter(p => p.stage === tab.value)))
const count = (t: Tab) => (t === 'all' ? parcels.value.length : parcels.value.filter(p => p.stage === t).length)

const cover = (item: ShopOrderRow['items'][number]) => item.product ? [...item.product.images].sort((a, b) => a.sort_order - b.sort_order)[0]?.url : undefined
const stageTone: Record<PurchaseStage, string> = {
  'to-pay': 'text-primary',
  'to-ship': 'text-[oklch(0.5_0.12_70)]',
  'to-receive': 'text-indigo',
  'completed': 'text-[oklch(0.45_0.1_150)]',
  'cancelled': 'text-muted-foreground',
}
</script>

<template>
  <div class="mx-auto max-w-4xl px-4 py-10">
    <h1 class="font-display text-4xl font-medium sm:text-5xl">My purchases</h1>

    <div class="mt-6 flex gap-1 overflow-x-auto border-b [scrollbar-width:none]" role="tablist">
      <button
        v-for="t in tabs"
        :key="t"
        role="tab"
        :aria-selected="tab === t"
        :class="cn('-mb-px shrink-0 border-b-2 px-4 pb-3 text-sm font-medium transition-colors', tab === t ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground')"
        @click="router.replace({ query: t === 'all' ? {} : { tab: t } })"
      >
        {{ t === 'all' ? 'All' : stageLabels[t] }}<span v-if="count(t)" class="ml-1 text-xs">({{ count(t) }})</span>
      </button>
    </div>

    <div v-if="loading" class="mt-6 grid gap-4"><div v-for="n in 2" :key="n" class="h-40 animate-pulse rounded-2xl bg-muted" /></div>

    <EmptyState v-else-if="!visible.length" class="mt-6" :title="orders.length ? 'Nothing here' : 'No orders yet'" :body="orders.length ? 'No parcels in this tab right now.' : 'When you buy something, you can follow it here.'">
      <Button v-if="!orders.length" as-child><RouterLink to="/shop">Shop the crafts</RouterLink></Button>
    </EmptyState>

    <div v-else class="mt-6 grid gap-4">
      <article v-for="p in visible" :key="p.shop.id" class="rounded-2xl border bg-card">
        <header class="flex items-center justify-between gap-3 border-b px-5 py-3 text-sm">
          <span class="flex items-center gap-2 font-medium"><StoreIcon class="size-4 text-primary" /> {{ p.shop.artisan?.shop_name ?? 'Shop' }}</span>
          <span :class="cn('font-semibold uppercase tracking-wide text-xs', stageTone[p.stage])">{{ stageLabels[p.stage] }}</span>
        </header>
        <RouterLink :to="`/orders/${p.order.id}`" class="block divide-y hover:bg-secondary/30">
          <div v-for="item in p.shop.items" :key="item.id" class="flex gap-4 px-5 py-4">
            <img v-if="cover(item)" :src="cover(item)" alt="" class="size-16 rounded-lg object-cover">
            <div v-else class="size-16 rounded-lg bg-muted" />
            <div class="min-w-0 flex-1">
              <p class="truncate font-medium">{{ item.product_name }}</p>
              <p class="text-sm text-muted-foreground">× {{ item.qty }}</p>
            </div>
            <p class="text-sm">{{ peso(item.unit_price * item.qty) }}</p>
          </div>
        </RouterLink>
        <footer class="flex flex-wrap items-center justify-between gap-3 border-t px-5 py-3">
          <span class="text-xs text-muted-foreground">Order {{ shortId(p.order.id) }} · {{ new Date(p.order.created_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) }}</span>
          <div class="flex items-center gap-3">
            <span class="text-sm">Shop total <span class="font-display text-lg">{{ peso(Number(p.shop.subtotal) + Number(p.shop.shipping_fee)) }}</span></span>
            <Button v-if="p.stage === 'to-pay'" as-child size="sm" class="rounded-full"><RouterLink :to="p.order.payment_method === 'mock' ? `/pay/${p.order.id}` : `/orders/${p.order.id}`">Pay now</RouterLink></Button>
            <Button v-else as-child size="sm" variant="outline" class="rounded-full"><RouterLink :to="`/orders/${p.order.id}`">{{ p.stage === 'completed' ? 'Review' : 'View order' }}</RouterLink></Button>
          </div>
        </footer>
      </article>
    </div>
  </div>
</template>
