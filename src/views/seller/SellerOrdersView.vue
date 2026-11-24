<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { SellerOrderRow } from '@/lib/orders'
import type { ShopOrderStatus } from '@/types/database'
import { MapPinIcon, PhoneIcon } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { peso } from '@/lib/format'
import { fetchShopOrders, paymentLabels, shortId, updateShopOrderStatus } from '@/lib/orders'
import { cn } from '@/lib/utils'
import { useSellerStore } from '@/stores/seller'

const route = useRoute()
const router = useRouter()
const seller = useSellerStore()
const rows = ref<SellerOrderRow[]>([])
const loading = ref(true)
const busy = ref<string | null>(null)

async function load() {
  if (!seller.shop) return
  loading.value = true
  try {
    rows.value = await fetchShopOrders(seller.shop.id)
  }
  finally {
    loading.value = false
  }
}
watch(() => seller.shop?.id, load, { immediate: true })

// Online orders can't ship until the buyer has paid.
const payable = (r: SellerOrderRow) => r.order.payment_method === 'cod' || r.order.payment_status === 'paid'

type Tab = 'to-ship' | 'unpaid' | 'shipped' | 'completed' | 'cancelled'
const tabs: { key: Tab, label: string, match: (r: SellerOrderRow) => boolean }[] = [
  { key: 'to-ship', label: 'To Ship', match: r => r.status === 'pending' && payable(r) },
  { key: 'unpaid', label: 'Unpaid', match: r => r.status === 'pending' && !payable(r) },
  { key: 'shipped', label: 'Shipping', match: r => r.status === 'shipped' },
  { key: 'completed', label: 'Completed', match: r => r.status === 'delivered' },
  { key: 'cancelled', label: 'Cancelled', match: r => r.status === 'cancelled' },
]
const tab = computed<Tab>(() => (tabs.some(t => t.key === route.query.tab) ? route.query.tab as Tab : 'to-ship'))
const visible = computed(() => rows.value.filter(tabs.find(t => t.key === tab.value)!.match))
const count = (key: Tab) => rows.value.filter(tabs.find(t => t.key === key)!.match).length

async function move(r: SellerOrderRow, status: ShopOrderStatus) {
  if (status === 'cancelled' && !await confirmAction({ title: `Cancel order ${shortId(r.order.id)}?`, body: 'The buyer is told it was cancelled and the items go back into your stock.', confirmLabel: 'Cancel order', cancelLabel: 'Keep it', destructive: true })) return
  busy.value = r.id
  try {
    await updateShopOrderStatus(r.id, status)
    toast.success({ shipped: 'Marked as shipped.', delivered: 'Marked as delivered.', cancelled: 'Order cancelled.', pending: '' }[status])
    await load()
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update the order')
  }
  finally {
    busy.value = null
  }
}

const date = (iso: string) => new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <section class="rounded-lg border bg-card">
      <div class="px-5 pt-5">
        <h1 class="text-lg font-semibold">My Orders</h1>
        <p class="text-sm text-muted-foreground">Pack, ship and confirm delivery for each order.</p>
      </div>
      <div class="mt-4 flex gap-6 overflow-x-auto border-b px-5 text-sm" role="tablist">
        <button
          v-for="t in tabs"
          :key="t.key"
          role="tab"
          :aria-selected="tab === t.key"
          :class="cn('-mb-px shrink-0 border-b-2 pb-3 font-medium transition-colors', tab === t.key ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground')"
          @click="router.replace({ query: t.key === 'to-ship' ? {} : { tab: t.key } })"
        >
          {{ t.label }} ({{ count(t.key) }})
        </button>
      </div>

      <div class="grid gap-4 p-5">
        <p v-if="loading" class="py-10 text-center text-sm text-muted-foreground">Loading…</p>
        <p v-else-if="!visible.length" class="py-12 text-center text-sm text-muted-foreground">
          {{ tab === 'to-ship' ? 'Nothing to ship right now.' : 'No orders here.' }}
        </p>
        <article v-for="r in visible" v-else :key="r.id" class="rounded-lg border">
          <header class="flex flex-wrap items-center justify-between gap-2 border-b bg-secondary/50 px-4 py-2.5 text-sm">
            <span class="font-medium">Order {{ shortId(r.order.id) }} <span class="font-normal text-muted-foreground">· {{ date(r.order.created_at) }}</span></span>
            <span :class="cn('rounded-full px-2.5 py-0.5 text-xs font-medium', r.order.payment_status === 'paid' ? 'bg-[oklch(0.93_0.06_150)] text-[oklch(0.4_0.1_150)]' : 'bg-mango/40')">
              {{ paymentLabels[r.order.payment_method] }} · {{ r.order.payment_status === 'paid' ? 'Paid' : r.order.payment_method === 'cod' ? `Collect ${peso(Number(r.subtotal) + Number(r.shipping_fee))}` : 'Awaiting payment' }}
            </span>
          </header>
          <div class="grid gap-4 p-4 md:grid-cols-[1.4fr_1fr_auto]">
            <ul class="grid content-start gap-1.5 text-sm">
              <li v-for="item in r.items" :key="item.id" class="flex justify-between gap-3">
                <span>{{ item.qty }} × {{ item.product_name }}</span>
                <span class="text-muted-foreground">{{ peso(item.unit_price * item.qty) }}</span>
              </li>
              <li class="mt-1 flex justify-between gap-3 border-t pt-2 text-xs text-muted-foreground">
                <span>Shipping {{ peso(r.shipping_fee) }} · Commission {{ peso(r.commission) }}</span>
                <span class="font-semibold text-foreground">{{ peso(Number(r.subtotal) + Number(r.shipping_fee)) }}</span>
              </li>
            </ul>
            <div class="text-sm">
              <p class="font-medium">{{ r.order.ship_recipient }}</p>
              <p class="flex items-center gap-1.5 text-muted-foreground"><PhoneIcon class="size-3.5" /> {{ r.order.ship_phone }}</p>
              <p class="mt-1 flex gap-1.5 text-muted-foreground"><MapPinIcon class="mt-0.5 size-3.5 shrink-0" /> {{ r.order.ship_address }}</p>
            </div>
            <div class="flex flex-col gap-2 md:items-end">
              <template v-if="r.status === 'pending'">
                <Button size="sm" class="rounded-full" :disabled="busy === r.id || !payable(r)" :title="payable(r) ? undefined : 'Wait for the buyer to pay'" @click="move(r, 'shipped')">Mark as shipped</Button>
                <Button size="sm" variant="ghost" class="rounded-full text-destructive" :disabled="busy === r.id || r.order.payment_status === 'paid'" @click="move(r, 'cancelled')">Cancel order</Button>
              </template>
              <Button v-else-if="r.status === 'shipped'" size="sm" class="rounded-full" :disabled="busy === r.id" @click="move(r, 'delivered')">Mark as delivered</Button>
              <span v-else-if="r.status === 'delivered'" class="text-xs text-muted-foreground">Delivered {{ r.delivered_at ? date(r.delivered_at) : '' }}</span>
              <span v-else class="text-xs text-muted-foreground">Cancelled</span>
            </div>
          </div>
        </article>
      </div>
    </section>
  </div>
</template>
