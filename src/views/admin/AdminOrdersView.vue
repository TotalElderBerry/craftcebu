<script setup lang="ts">
import type { AdminOrder } from '@/lib/admin'
import type { ShopOrderStatus } from '@/types/database'
import { SearchIcon, StoreIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import OrderTimeline from '@/components/OrderTimeline.vue'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { fetchAllOrders } from '@/lib/admin'
import { peso } from '@/lib/format'
import { paymentLabels, shortId, updateShopOrderStatus } from '@/lib/orders'
import { cn } from '@/lib/utils'

const route = useRoute()
const router = useRouter()
const rows = ref<AdminOrder[]>([])
const loading = ref(true)
const search = ref('')
const method = ref<'all' | AdminOrder['payment_method']>('all')
const selectedId = ref<string | null>(null)
const busy = ref<string | null>(null)

async function load() {
  loading.value = true
  try {
    rows.value = await fetchAllOrders()
  }
  finally {
    loading.value = false
  }
}
onMounted(load)

// One status per order, from its parcels and payment.
type Stage = 'unpaid' | 'to-ship' | 'shipping' | 'completed' | 'cancelled'
function stageOf(o: AdminOrder): Stage {
  const live = o.shops.filter(s => s.status !== 'cancelled')
  if (!live.length) return 'cancelled'
  if (live.every(s => s.status === 'delivered')) return 'completed'
  if (o.payment_method !== 'cod' && o.payment_status !== 'paid') return 'unpaid'
  if (live.some(s => s.status === 'pending')) return 'to-ship'
  return 'shipping'
}
const tabs: { key: 'all' | Stage, label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'unpaid', label: 'Unpaid' },
  { key: 'to-ship', label: 'To Ship' },
  { key: 'shipping', label: 'Shipping' },
  { key: 'completed', label: 'Completed' },
  { key: 'cancelled', label: 'Cancelled' },
]
const tab = computed(() => (tabs.some(t => t.key === route.query.status) ? route.query.status as 'all' | Stage : 'all'))
const count = (key: 'all' | Stage) => rows.value.filter(o => key === 'all' || stageOf(o) === key).length

const visible = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rows.value.filter(o =>
    (tab.value === 'all' || stageOf(o) === tab.value)
    && (method.value === 'all' || o.payment_method === method.value)
    && (!q || o.id.startsWith(q) || shortId(o.id).toLowerCase().startsWith(q) || o.buyer?.full_name.toLowerCase().includes(q) || o.ship_recipient.toLowerCase().includes(q)),
  )
})

const selected = computed(() => rows.value.find(o => o.id === selectedId.value) ?? null)
const open = computed({ get: () => !!selected.value, set: v => { if (!v) selectedId.value = null } })

const stageLabel: Record<Stage, string> = { 'unpaid': 'Unpaid', 'to-ship': 'To ship', 'shipping': 'Shipping', 'completed': 'Completed', 'cancelled': 'Cancelled' }
const stageTone: Record<Stage, string> = {
  'unpaid': 'bg-primary/10 text-primary',
  'to-ship': 'bg-mango/40 text-ink',
  'shipping': 'bg-indigo/10 text-indigo',
  'completed': 'bg-[oklch(0.93_0.06_150)] text-[oklch(0.4_0.1_150)]',
  'cancelled': 'bg-secondary text-muted-foreground',
}

async function move(shopId: string, status: ShopOrderStatus) {
  busy.value = shopId
  try {
    await updateShopOrderStatus(shopId, status)
    toast.success('Parcel updated.')
    await load()
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update the parcel')
  }
  finally {
    busy.value = null
  }
}

const date = (iso: string) => new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <AdminCard title="All Orders" :subtitle="`${rows.length} orders`">
      <template #actions>
        <select v-model="method" aria-label="Payment method" class="h-10 rounded-md border bg-card px-3 text-sm">
          <option value="all">All payments</option>
          <option value="cod">Cash on delivery</option>
          <option value="maya">Maya</option>
          <option value="mock">Demo payment</option>
        </select>
        <label class="flex h-10 items-center gap-2 rounded-md border px-3 text-sm">
          <SearchIcon class="size-4 text-muted-foreground" />
          <input v-model="search" type="search" placeholder="Order ID or buyer" aria-label="Search orders" class="w-full min-w-0 bg-transparent outline-none sm:w-40">
        </label>
      </template>
      <template #tabs>
        <TabButton v-for="t in tabs" :key="t.key" :active="tab === t.key" :count="count(t.key)" @select="router.replace({ query: t.key === 'all' ? {} : { status: t.key } })">{{ t.label }}</TabButton>
      </template>
      <!-- Phones: one tappable card per order -->
      <ul class="divide-y md:hidden">
        <li v-if="loading" class="px-5 py-10 text-center text-sm text-muted-foreground">Loading…</li>
        <li v-else-if="!visible.length" class="px-5 py-12 text-center text-sm text-muted-foreground">No orders here.</li>
        <li v-for="o in visible" v-else :key="o.id">
          <button class="grid w-full gap-1 px-4 py-4 text-left text-sm hover:bg-secondary/40" @click="selectedId = o.id">
            <span class="flex items-center justify-between gap-2">
              <span class="font-semibold">{{ shortId(o.id) }} <span class="font-normal text-muted-foreground">· {{ date(o.created_at) }}</span></span>
              <span :class="cn('shrink-0 rounded-full px-2.5 py-0.5 text-xs font-medium', stageTone[stageOf(o)])">{{ stageLabel[stageOf(o)] }}</span>
            </span>
            <span class="truncate">{{ o.buyer?.full_name || o.ship_recipient }} <span class="text-muted-foreground">· {{ o.shops.map(s => s.artisan?.shop_name).join(', ') }}</span></span>
            <span class="flex justify-between text-muted-foreground"><span>{{ paymentLabels[o.payment_method] }} · {{ o.payment_status }}</span><span class="font-medium text-foreground">{{ peso(o.total) }}</span></span>
          </button>
        </li>
      </ul>

      <div class="hidden overflow-x-auto md:block">
        <table class="w-full min-w-[860px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Order</th>
              <th class="px-5 py-3 font-medium">Buyer</th>
              <th class="px-5 py-3 font-medium">Shops</th>
              <th class="px-5 py-3 font-medium">Payment</th>
              <th class="px-5 py-3 font-medium">Total</th>
              <th class="px-5 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="6" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!visible.length"><td colspan="6" class="px-5 py-12 text-center text-muted-foreground">No orders here.</td></tr>
            <tr v-for="o in visible" v-else :key="o.id" class="cursor-pointer hover:bg-secondary/40" tabindex="0" @click="selectedId = o.id" @keydown.enter="selectedId = o.id">
              <td class="px-5 py-3">
                <p class="font-medium">{{ shortId(o.id) }}</p>
                <p class="text-xs text-muted-foreground">{{ date(o.created_at) }}</p>
              </td>
              <td class="px-5 py-3">
                <p>{{ o.buyer?.full_name || o.ship_recipient }}</p>
                <p class="text-xs text-muted-foreground">{{ o.buyer?.email }}</p>
              </td>
              <td class="px-5 py-3 text-muted-foreground">{{ o.shops.map(s => s.artisan?.shop_name).join(', ') }}</td>
              <td class="px-5 py-3">
                <p>{{ paymentLabels[o.payment_method] }}</p>
                <p :class="cn('text-xs', o.payment_status === 'paid' ? 'text-[oklch(0.45_0.1_150)]' : o.payment_status === 'failed' ? 'text-destructive' : 'text-muted-foreground')">{{ o.payment_status }}</p>
              </td>
              <td class="px-5 py-3 font-medium tabular-nums">{{ peso(o.total) }}</td>
              <td class="px-5 py-3"><span :class="cn('rounded-full px-2.5 py-0.5 text-xs font-medium', stageTone[stageOf(o)])">{{ stageLabel[stageOf(o)] }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </AdminCard>

    <Sheet v-model:open="open">
      <SheetContent class="w-full overflow-y-auto sm:max-w-lg">
        <template v-if="selected">
          <SheetHeader>
            <SheetTitle class="font-display text-2xl font-medium">Order {{ shortId(selected.id) }}</SheetTitle>
            <SheetDescription>{{ new Date(selected.created_at).toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' }) }} · {{ paymentLabels[selected.payment_method] }} · {{ selected.payment_status }}</SheetDescription>
          </SheetHeader>
          <div class="grid gap-5 px-4 pb-6 text-sm">
            <section class="rounded-lg bg-secondary p-4">
              <p class="font-medium">{{ selected.ship_recipient }} · {{ selected.ship_phone }}</p>
              <p class="text-muted-foreground">{{ selected.ship_address }}</p>
              <p v-if="selected.buyer?.email" class="mt-1 text-xs text-muted-foreground">Account: {{ selected.buyer.email }}</p>
              <p v-if="selected.maya_checkout_id" class="mt-1 text-xs break-all text-muted-foreground">Maya checkout: {{ selected.maya_checkout_id }}</p>
            </section>

            <section v-for="s in selected.shops" :key="s.id" class="rounded-lg border">
              <header class="flex items-center gap-2 border-b px-4 py-2.5 font-medium"><StoreIcon class="size-4 text-primary" /> {{ s.artisan?.shop_name }}</header>
              <div class="px-4 pt-4"><OrderTimeline :status="s.status" :placed-at="selected.created_at" :shipped-at="s.shipped_at" :delivered-at="s.delivered_at" /></div>
              <ul class="mt-3 grid gap-1 border-t px-4 py-3">
                <li v-for="i in s.items" :key="i.id" class="flex justify-between gap-3"><span>{{ i.qty }} × {{ i.product_name }}</span><span>{{ peso(i.unit_price * i.qty) }}</span></li>
                <li class="flex justify-between gap-3 text-xs text-muted-foreground"><span>Shipping {{ peso(s.shipping_fee) }} · Commission {{ peso(s.commission) }}</span><span class="font-medium text-foreground">{{ peso(Number(s.subtotal) + Number(s.shipping_fee)) }}</span></li>
              </ul>
              <div v-if="s.status === 'pending' || s.status === 'shipped'" class="flex gap-2 border-t px-4 py-3">
                <Button v-if="s.status === 'pending'" size="sm" class="rounded-full" :disabled="busy === s.id || (selected.payment_method !== 'cod' && selected.payment_status !== 'paid')" @click="move(s.id, 'shipped')">Mark shipped</Button>
                <Button v-if="s.status === 'shipped'" size="sm" class="rounded-full" :disabled="busy === s.id" @click="move(s.id, 'delivered')">Mark delivered</Button>
                <Button v-if="s.status === 'pending' && selected.payment_status !== 'paid'" size="sm" variant="ghost" class="rounded-full text-destructive" :disabled="busy === s.id" @click="move(s.id, 'cancelled')">Cancel parcel</Button>
              </div>
            </section>

            <p class="flex items-baseline justify-between rounded-lg bg-secondary p-4">
              <span class="text-muted-foreground">Order total</span><span class="font-display text-2xl">{{ peso(selected.total) }}</span>
            </p>
          </div>
        </template>
      </SheetContent>
    </Sheet>
  </div>
</template>
