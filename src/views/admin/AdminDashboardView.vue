<script setup lang="ts">
import { CheckCircle2Icon, ChevronRightIcon, CircleIcon, TrendingDownIcon, TrendingUpIcon } from '@lucide/vue'
import { computed, onMounted, ref, watch } from 'vue'
import TrendChart from '@/components/admin/TrendChart.vue'
import { actionLabels } from '@/lib/admin'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

// --- To do list --------------------------------------------------------------
const head = { count: 'exact' as const, head: true }
const todos = ref([
  { key: 'applications', label: 'Pending Applications', to: '/admin/applications', value: null as number | null, query: () => supabase.from('artisans').select('*', head).eq('status', 'pending') },
  { key: 'toShip', label: 'To Ship', to: '/admin/orders?status=to-ship', value: null as number | null, query: () => supabase.from('order_shops').select('*', head).eq('status', 'pending') },
  { key: 'unpaidCod', label: 'Unpaid COD', to: '/admin/orders', value: null as number | null, query: () => supabase.from('orders').select('*', head).eq('payment_method', 'cod').eq('payment_status', 'unpaid') },
  { key: 'cancelled', label: 'Cancelled Orders', to: '/admin/orders?status=cancelled', value: null as number | null, query: () => supabase.from('order_shops').select('*', head).eq('status', 'cancelled') },
  { key: 'soldOut', label: 'Sold Out Products', to: '/admin/products', value: null as number | null, query: () => supabase.from('products').select('*', head).eq('stock', 0) },
  { key: 'lowStock', label: 'Low Stock (≤5)', to: '/admin/products', value: null as number | null, query: () => supabase.from('products').select('*', head).gt('stock', 0).lte('stock', 5) },
  { key: 'payouts', label: 'Shops to Settle', to: '/admin/payouts', value: null as number | null, query: () => supabase.rpc('payout_balances') },
  { key: 'banned', label: 'Banned Users', to: '/admin/users', value: null as number | null, query: () => supabase.from('profiles').select('*', head).eq('is_banned', true) },
])

// --- Business insights -------------------------------------------------------
type Range = 'today' | '7d' | '30d'
const ranges: { key: Range, label: string }[] = [
  { key: 'today', label: 'Today' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
]
const range = ref<Range>('7d')

interface OrderRow { created_at: string, total: number, payment_status: string }
const orders = ref<OrderRow[]>([])
const buyers = ref<{ created_at: string }[]>([])
const asOf = ref(new Date())

// Each range compares against the period of the same length just before it.
function bounds(r: Range) {
  const now = new Date()
  const start = new Date(now)
  if (r === 'today') start.setHours(0, 0, 0, 0)
  else {
    start.setHours(0, 0, 0, 0)
    start.setDate(start.getDate() - (r === '7d' ? 6 : 29))
  }
  const span = r === 'today' ? 86_400_000 : now.getTime() - start.getTime()
  return { start, prevStart: new Date(start.getTime() - span), now }
}

interface ShopSaleRow { subtotal: number, commission: number, status: string, order: { created_at: string, payment_method: string } | null, artisan: { shop_name: string, town: { name: string } | null } | null }
const shopRows = ref<ShopSaleRow[]>([])

async function loadInsights() {
  const { prevStart } = bounds(range.value)
  const shopRes = await supabase
    .from('order_shops')
    .select('subtotal, commission, status, order:orders!inner(created_at, payment_method), artisan:artisans(shop_name, town:towns(name))')
    .neq('status', 'cancelled')
    .gte('order.created_at', prevStart.toISOString())
  shopRows.value = (shopRes.data ?? []) as unknown as ShopSaleRow[]
  const [o, b] = await Promise.all([
    supabase.from('orders').select('created_at, total, payment_status').gte('created_at', prevStart.toISOString()),
    supabase.from('profiles').select('created_at').eq('role', 'buyer').gte('created_at', prevStart.toISOString()),
  ])
  orders.value = (o.data ?? []).map(r => ({ ...r, total: Number(r.total) }))
  buyers.value = b.data ?? []
  asOf.value = new Date()
}

const peso = (v: number) => `₱${v.toLocaleString('en-PH', { maximumFractionDigits: 0 })}`
const plain = (v: number) => v.toLocaleString('en-PH', { maximumFractionDigits: 0 })

// Merchandise sales (non-cancelled parcels) in the selected range, by shop and by town.
// shopRows reaches back to the previous period for comparisons; these use the current one.
const currentShopRows = computed(() => {
  const { start } = bounds(range.value)
  return shopRows.value.filter(r => r.order && new Date(r.order.created_at) >= start)
})

function rank(key: (r: ShopSaleRow) => string | undefined) {
  const totals = new Map<string, { sales: number, orders: number }>()
  for (const r of currentShopRows.value) {
    const k = key(r) ?? 'Unknown'
    const t = totals.get(k) ?? { sales: 0, orders: 0 }
    t.sales += Number(r.subtotal)
    t.orders += 1
    totals.set(k, t)
  }
  return [...totals.entries()].map(([name, t]) => ({ name, ...t })).sort((a, b) => b.sales - a.sales)
}
const topShops = computed(() => rank(r => r.artisan?.shop_name).slice(0, 5))
const byTown = computed(() => rank(r => r.artisan?.town?.name))
const townMax = computed(() => Math.max(1, ...byTown.value.map(t => t.sales)))

const metrics = computed(() => {
  const { start } = bounds(range.value)
  const inNow = (d: string) => new Date(d) >= start
  const cur = orders.value.filter(o => inNow(o.created_at))
  const prev = orders.value.filter(o => !inNow(o.created_at))
  const paid = (rows: OrderRow[]) => rows.filter(o => o.payment_status === 'paid')
  const sum = (rows: OrderRow[]) => rows.reduce((s, o) => s + o.total, 0)
  const curPaid = paid(cur)
  const prevPaid = paid(prev)
  return [
    { key: 'sales', label: 'Sales', format: peso, now: sum(curPaid), before: sum(prevPaid) },
    { key: 'orders', label: 'Orders', format: plain, now: cur.length, before: prev.length },
    { key: 'aov', label: 'Avg. order value', format: peso, now: curPaid.length ? sum(curPaid) / curPaid.length : 0, before: prevPaid.length ? sum(prevPaid) / prevPaid.length : 0 },
    { key: 'buyers', label: 'New buyers', format: plain, now: buyers.value.filter(b => inNow(b.created_at)).length, before: buyers.value.filter(b => !inNow(b.created_at)).length },
  ]
})
const activeMetric = ref('sales')
const selected = computed(() => metrics.value.find(m => m.key === activeMetric.value)!)

function change(now: number, before: number) {
  if (before === 0) return now === 0 ? 0 : null
  return ((now - before) / before) * 100
}

// Buckets for the charts: hours for today, days otherwise.
const buckets = computed(() => {
  const { start, now } = bounds(range.value)
  const hourly = range.value === 'today'
  const buckets: { label: string, from: number, to: number }[] = []
  if (hourly) {
    for (let h = 0; h <= now.getHours(); h++) {
      const from = new Date(start)
      from.setHours(h)
      buckets.push({ label: `${h}:00`, from: from.getTime(), to: from.getTime() + 3_600_000 })
    }
  }
  else {
    for (let d = new Date(start); d <= now; d.setDate(d.getDate() + 1)) {
      buckets.push({ label: d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }), from: d.getTime(), to: d.getTime() + 86_400_000 })
    }
  }
  return buckets
})

const within = (iso: string, b: { from: number, to: number }) => {
  const t = new Date(iso).getTime()
  return t >= b.from && t < b.to
}

const series = computed(() => {
  return buckets.value.map((b) => {
    const rows = orders.value.filter(o => within(o.created_at, b))
    const paidRows = rows.filter(o => o.payment_status === 'paid')
    const sales = paidRows.reduce((s, o) => s + o.total, 0)
    const value = {
      sales,
      orders: rows.length,
      aov: paidRows.length ? sales / paidRows.length : 0,
      buyers: buyers.value.filter(u => within(u.created_at, b)).length,
    }[activeMetric.value] ?? 0
    return { label: b.label, value }
  })
})

// --- Platform earnings -----------------------------------------------------------
// CraftCebu earns its commission on each shop's subtotal. It counts as earned
// once the parcel is delivered; until then it's pending (cancelled parcels earn
// nothing and aren't loaded). Periods follow when the order was placed.
const pesoCents = (v: number) => `₱${v.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
const commissionOf = (rows: ShopSaleRow[]) => rows.reduce((sum, r) => sum + Number(r.commission), 0)

const earnings = computed(() => {
  const { start } = bounds(range.value)
  const cur = currentShopRows.value
  const prev = shopRows.value.filter(r => r.order && new Date(r.order.created_at) < start)
  const delivered = (rows: ShopSaleRow[]) => rows.filter(r => r.status === 'delivered')
  return {
    earned: commissionOf(delivered(cur)),
    earnedBefore: commissionOf(delivered(prev)),
    pending: commissionOf(cur.filter(r => r.status !== 'delivered')),
    online: commissionOf(cur.filter(r => r.order?.payment_method !== 'cod')),
    cod: commissionOf(cur.filter(r => r.order?.payment_method === 'cod')),
    sales: cur.reduce((sum, r) => sum + Number(r.subtotal), 0),
  }
})

const earningsSeries = computed(() => buckets.value.map(b => ({
  label: b.label,
  value: commissionOf(currentShopRows.value.filter(r => r.order && within(r.order.created_at, b))),
})))

// --- Side column ---------------------------------------------------------------
const settings = ref<Record<string, unknown>>({})
const activity = ref<{ action: string, created_at: string, actor: { full_name: string } | null }[]>([])
const setup = ref({ categories: false, verified: false, product: false, order: false })


async function loadSide() {
  const [s, a, cat, ver, prod, ord] = await Promise.all([
    supabase.from('settings').select('key, value'),
    supabase.from('activity_log').select('action, created_at, actor:profiles(full_name)').order('created_at', { ascending: false }).limit(5),
    supabase.from('categories').select('*', head),
    supabase.from('artisans').select('*', head).eq('status', 'verified'),
    supabase.from('products').select('*', head),
    supabase.from('orders').select('*', head),
  ])
  settings.value = Object.fromEntries((s.data ?? []).map(r => [r.key, r.value]))
  activity.value = (a.data ?? []) as unknown as typeof activity.value
  setup.value = {
    categories: (cat.count ?? 0) > 0,
    verified: (ver.count ?? 0) > 0,
    product: (prod.count ?? 0) > 0,
    order: (ord.count ?? 0) > 0,
  }
}

const checklist = computed(() => [
  { label: 'Seed towns and craft categories', done: setup.value.categories },
  { label: 'Approve the first artisan', done: setup.value.verified },
  { label: 'First product listed', done: setup.value.product },
  { label: 'First order placed', done: setup.value.order },
])

onMounted(async () => {
  await Promise.all([
    ...todos.value.map(async (t) => {
      const res = await t.query() as { count: number | null, data: unknown }
      t.value = res.count ?? (Array.isArray(res.data) ? res.data.length : 0)
    }),
    loadInsights(),
    loadSide(),
  ])
})
watch(range, loadInsights)

const timeAgo = (iso: string) => {
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60_000)
  if (mins < 60) return `${mins}m ago`
  if (mins < 1440) return `${Math.round(mins / 60)}h ago`
  return new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="mx-auto grid max-w-7xl gap-4 xl:grid-cols-[1fr_320px]">
    <div class="grid min-w-0 gap-4">
      <!-- To do list -->
      <section class="rounded-lg border bg-card p-5">
        <h1 class="text-lg font-semibold">To Do List</h1>
        <p class="text-sm text-muted-foreground">Things you need to deal with</p>
        <div class="mt-4 grid grid-cols-2 gap-px overflow-hidden rounded-md border bg-border sm:grid-cols-4">
          <RouterLink v-for="t in todos" :key="t.key" :to="t.to" class="flex flex-col items-center gap-1 bg-card px-2 py-4 text-center transition-colors hover:bg-secondary/50">
            <span :class="cn('text-2xl font-semibold tabular-nums', t.value ? 'text-primary' : 'text-foreground')">{{ t.value ?? '–' }}</span>
            <span class="text-xs text-muted-foreground">{{ t.label }}</span>
          </RouterLink>
        </div>
      </section>

      <!-- Business insights -->
      <section class="rounded-lg border bg-card p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">Business Insights</h2>
            <p class="text-sm text-muted-foreground">
              Real-time data as of {{ asOf.toLocaleTimeString('en-PH', { hour: '2-digit', minute: '2-digit' }) }} (GMT+8)
            </p>
          </div>
          <div class="flex rounded-md border p-0.5 text-sm" role="group" aria-label="Date range">
            <button
              v-for="r in ranges"
              :key="r.key"
              :aria-pressed="range === r.key"
              :class="cn('rounded px-3 py-1.5 font-medium transition-colors', range === r.key ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground')"
              @click="range = r.key"
            >
              {{ r.label }}
            </button>
          </div>
        </div>

        <div class="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <button
            v-for="m in metrics"
            :key="m.key"
            :aria-pressed="activeMetric === m.key"
            :class="cn('rounded-md border p-4 text-left transition-colors', activeMetric === m.key ? 'border-primary bg-primary/5 shadow-[inset_0_3px_0_var(--primary)]' : 'hover:border-foreground/30')"
            @click="activeMetric = m.key"
          >
            <span class="text-xs text-muted-foreground">{{ m.label }}</span>
            <span class="mt-1 block text-2xl font-semibold tabular-nums">{{ m.format(m.now) }}</span>
            <span class="mt-1 flex items-center gap-1 text-xs text-muted-foreground">
              vs previous period
              <template v-if="change(m.now, m.before) === null"><span class="font-medium text-foreground">new</span></template>
              <template v-else>
                <TrendingUpIcon v-if="change(m.now, m.before)! > 0" class="size-3 text-[oklch(0.55_0.13_150)]" />
                <TrendingDownIcon v-else-if="change(m.now, m.before)! < 0" class="size-3 text-destructive" />
                <span class="font-medium text-foreground">{{ Math.abs(change(m.now, m.before)!).toFixed(0) }}%</span>
              </template>
            </span>
          </button>
        </div>

        <div class="mt-6">
          <p class="mb-2 text-sm font-medium">{{ selected.label }} · {{ ranges.find(r => r.key === range)?.label }}</p>
          <TrendChart :points="series" :format="selected.format" :name="selected.label" />
          <p v-if="!orders.length" class="mt-2 text-center text-xs text-muted-foreground">No orders in this period yet. Checkout arrives in Milestone 4.</p>
        </div>
      </section>

      <!-- Platform earnings -->
      <section class="rounded-lg border bg-card p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">Platform earnings</h2>
            <p class="text-sm text-muted-foreground">CraftCebu's {{ settings.commission_percent ?? '–' }}% commission on orders placed {{ ranges.find(r => r.key === range)?.label.toLowerCase() }}</p>
          </div>
          <RouterLink to="/admin/payouts" class="flex items-center text-xs text-muted-foreground hover:text-primary">Payouts <ChevronRightIcon class="size-3" /></RouterLink>
        </div>

        <div class="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <div class="rounded-md border border-primary bg-primary/5 p-4 shadow-[inset_0_3px_0_var(--primary)]">
            <span class="text-xs text-muted-foreground">Earned</span>
            <span class="mt-1 block text-2xl font-semibold tabular-nums">{{ pesoCents(earnings.earned) }}</span>
            <span class="mt-1 flex items-center gap-1 text-xs text-muted-foreground">
              Delivered orders ·
              <template v-if="change(earnings.earned, earnings.earnedBefore) === null"><span class="font-medium text-foreground">new</span></template>
              <template v-else>
                <TrendingUpIcon v-if="change(earnings.earned, earnings.earnedBefore)! > 0" class="size-3 text-[oklch(0.55_0.13_150)]" />
                <TrendingDownIcon v-else-if="change(earnings.earned, earnings.earnedBefore)! < 0" class="size-3 text-destructive" />
                <span class="font-medium text-foreground">{{ Math.abs(change(earnings.earned, earnings.earnedBefore)!).toFixed(0) }}%</span>
              </template>
            </span>
          </div>
          <div class="rounded-md border p-4">
            <span class="text-xs text-muted-foreground">Pending</span>
            <span class="mt-1 block text-2xl font-semibold tabular-nums">{{ pesoCents(earnings.pending) }}</span>
            <span class="mt-1 block text-xs text-muted-foreground">Earned once delivered</span>
          </div>
          <div class="rounded-md border p-4">
            <span class="text-xs text-muted-foreground">From online payments</span>
            <span class="mt-1 block text-2xl font-semibold tabular-nums">{{ pesoCents(earnings.online) }}</span>
            <span class="mt-1 block text-xs text-muted-foreground">Kept when paying shops</span>
          </div>
          <div class="rounded-md border p-4">
            <span class="text-xs text-muted-foreground">From cash on delivery</span>
            <span class="mt-1 block text-2xl font-semibold tabular-nums">{{ pesoCents(earnings.cod) }}</span>
            <span class="mt-1 block text-xs text-muted-foreground">Collected from shops</span>
          </div>
        </div>

        <div class="mt-6">
          <p class="mb-2 text-sm font-medium">Commission · {{ ranges.find(r => r.key === range)?.label }}</p>
          <TrendChart :points="earningsSeries" :format="pesoCents" name="Commission" />
          <p class="mt-2 text-center text-xs text-muted-foreground">
            {{ earnings.sales ? `${pesoCents(earnings.earned + earnings.pending)} on ${pesoCents(earnings.sales)} of merchandise sales` : 'No orders in this period yet.' }}
          </p>
        </div>
      </section>

      <div class="grid gap-4 lg:grid-cols-2">
        <section class="rounded-lg border bg-card p-5">
          <h2 class="font-semibold">Top shops</h2>
          <p class="text-sm text-muted-foreground">Merchandise sales, {{ ranges.find(r => r.key === range)?.label.toLowerCase() }}</p>
          <ol v-if="topShops.length" class="mt-4 grid gap-3 text-sm">
            <li v-for="(s, i) in topShops" :key="s.name" class="flex items-center gap-3">
              <span class="w-4 text-muted-foreground tabular-nums">{{ i + 1 }}</span>
              <span class="min-w-0 flex-1 truncate font-medium">{{ s.name }}</span>
              <span class="text-xs text-muted-foreground">{{ s.orders }} {{ s.orders === 1 ? 'order' : 'orders' }}</span>
              <span class="w-20 text-right font-medium tabular-nums">{{ peso(s.sales) }}</span>
            </li>
          </ol>
          <p v-else class="mt-4 text-sm text-muted-foreground">No sales in this period.</p>
        </section>

        <section class="rounded-lg border bg-card p-5">
          <h2 class="font-semibold">Sales by town</h2>
          <p class="text-sm text-muted-foreground">Where this period's pieces were made</p>
          <ul v-if="byTown.length" class="mt-4 grid gap-3 text-sm">
            <li v-for="t in byTown" :key="t.name" class="grid grid-cols-[7rem_1fr_auto] items-center gap-3">
              <span class="truncate">{{ t.name }}</span>
              <span class="h-2 rounded-full bg-secondary" :title="`${t.name}: ${peso(t.sales)}`">
                <span class="block h-full rounded-full bg-primary" :style="{ width: `${(t.sales / townMax) * 100}%` }" />
              </span>
              <span class="text-right font-medium tabular-nums">{{ peso(t.sales) }}</span>
            </li>
          </ul>
          <p v-else class="mt-4 text-sm text-muted-foreground">No sales in this period.</p>
        </section>
      </div>
    </div>

    <!-- Side column -->
    <div class="grid content-start gap-4">
      <section class="rounded-lg border bg-card p-5">
        <p class="text-sm text-muted-foreground">Maayong adlaw,</p>
        <p class="font-display text-2xl font-medium">{{ auth.profile?.full_name || 'Owner' }}</p>
        <dl class="mt-4 grid grid-cols-2 gap-3 text-sm">
          <div class="rounded-md bg-secondary p-3">
            <dt class="text-xs text-muted-foreground">Commission</dt>
            <dd class="mt-0.5 font-semibold">{{ settings.commission_percent ?? '–' }}%</dd>
          </div>
          <div class="rounded-md bg-secondary p-3">
            <dt class="text-xs text-muted-foreground">Shipping / shop</dt>
            <dd class="mt-0.5 font-semibold">₱{{ settings.shipping_fee_per_shop ?? '–' }}</dd>
          </div>
        </dl>
      </section>

      <section class="rounded-lg border bg-card p-5">
        <h2 class="font-semibold">Launch checklist</h2>
        <ul class="mt-3 grid gap-2.5 text-sm">
          <li v-for="c in checklist" :key="c.label" class="flex items-center gap-2.5">
            <CheckCircle2Icon v-if="c.done" class="size-4 text-[oklch(0.55_0.13_150)]" aria-label="Done" />
            <CircleIcon v-else class="size-4 text-muted-foreground" aria-label="Not done" />
            <span :class="c.done ? 'text-muted-foreground line-through' : ''">{{ c.label }}</span>
          </li>
        </ul>
      </section>

      <section class="rounded-lg border bg-card p-5">
        <div class="flex items-center justify-between">
          <h2 class="font-semibold">Recent activity</h2>
          <RouterLink to="/admin/activity" class="flex items-center text-xs text-muted-foreground hover:text-primary">More <ChevronRightIcon class="size-3" /></RouterLink>
        </div>
        <ul v-if="activity.length" class="mt-3 grid gap-3 text-sm">
          <li v-for="a in activity" :key="a.created_at" class="flex justify-between gap-3">
            <span>{{ actionLabels[a.action] ?? a.action }}</span>
            <span class="shrink-0 text-xs text-muted-foreground">{{ timeAgo(a.created_at) }}</span>
          </li>
        </ul>
        <p v-else class="mt-3 text-sm text-muted-foreground">Approvals, suspensions and payouts will show up here.</p>
      </section>
    </div>
  </div>
</template>
