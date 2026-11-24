<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { OrderRow } from '@/lib/orders'
import { ArrowLeftIcon, CheckCircle2Icon, CreditCardIcon, MapPinIcon, StarIcon, StoreIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { toast } from 'vue-sonner'
import EmptyState from '@/components/catalog/EmptyState.vue'
import OrderTimeline from '@/components/OrderTimeline.vue'
import ReviewForm from '@/components/ReviewForm.vue'
import { Button } from '@/components/ui/button'
import { peso } from '@/lib/format'
import { cancelOrder, fetchOrder, paymentLabels, shortId, startMayaCheckout } from '@/lib/orders'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'

const route = useRoute()
const id = route.params.id as string
const order = ref<OrderRow | null>(null)
const loading = ref(true)
const cancelling = ref(false)
const justPlaced = computed(() => route.query.placed === '1')

// The buyer's reviews for this order's items, keyed by order item.
const myReviews = ref<Record<string, { rating: number, comment: string }>>({})
const reviewing = ref<string | null>(null)

async function load() {
  order.value = await fetchOrder(id)
  const itemIds = order.value?.shops.flatMap(s => s.items.map(i => i.id)) ?? []
  if (itemIds.length) {
    const { data } = await supabase.from('reviews').select('order_item_id, rating, comment').in('order_item_id', itemIds)
    myReviews.value = Object.fromEntries((data ?? []).map(r => [r.order_item_id, r]))
  }
}
onMounted(async () => {
  try {
    await load()
  }
  finally {
    loading.value = false
  }
})

const canCancel = computed(() => !!order.value && order.value.payment_status !== 'paid' && order.value.shops.every(s => s.status === 'pending'))
const needsPayment = computed(() => !!order.value && order.value.payment_method !== 'cod' && order.value.payment_status === 'unpaid' && order.value.shops.some(s => s.status !== 'cancelled'))
const openingMaya = ref(false)

async function payWithMaya() {
  openingMaya.value = true
  try {
    window.location.href = await startMayaCheckout(id)
  }
  catch (e) {
    toast.error((e as Error).message)
    openingMaya.value = false
  }
}

const paymentText = computed(() => {
  if (!order.value) return ''
  const { payment_method: m, payment_status: s } = order.value
  if (s === 'paid') return 'Paid'
  if (s === 'failed') return 'Payment failed'
  return m === 'cod' ? 'Pay the courier on delivery' : 'Waiting for payment'
})

async function cancel() {
  if (!await confirmAction({ title: 'Cancel this order?', body: 'Every parcel in it is cancelled and the pieces go back to the makers\' shops.', confirmLabel: 'Cancel order', cancelLabel: 'Keep it', destructive: true })) return
  cancelling.value = true
  try {
    await cancelOrder(id)
    await load()
    toast.success('Order cancelled.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not cancel')
  }
  finally {
    cancelling.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-4xl px-4 py-10">
    <RouterLink to="/orders" class="-my-2 inline-flex items-center gap-1 py-2 text-sm text-muted-foreground hover:text-foreground"><ArrowLeftIcon class="size-4" /> My purchases</RouterLink>

    <div v-if="loading" class="mt-6 h-96 animate-pulse rounded-2xl bg-muted" />
    <EmptyState v-else-if="!order" class="mt-6" title="Order not found" body="It may belong to another account." />

    <template v-else>
      <div v-if="justPlaced && order.payment_status !== 'failed'" class="mt-6 flex items-center gap-4 rounded-2xl bg-[oklch(0.95_0.04_150)] p-5 text-[oklch(0.3_0.08_150)]">
        <CheckCircle2Icon class="size-8 shrink-0" />
        <div>
          <p class="font-display text-2xl font-medium">Salamat! Your order is in.</p>
          <p class="text-sm">Each maker will pack and ship their part. You'll see updates here.</p>
        </div>
      </div>

      <div class="mt-6 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 class="font-display text-4xl font-medium">Order {{ shortId(order.id) }}</h1>
          <p class="mt-1 text-sm text-muted-foreground">Placed {{ new Date(order.created_at).toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' }) }}</p>
        </div>
        <div class="flex gap-2">
          <Button v-if="needsPayment && order.payment_method === 'maya'" :disabled="openingMaya" @click="payWithMaya">{{ openingMaya ? 'Opening Maya…' : 'Pay with Maya' }}</Button>
          <Button v-else-if="needsPayment" as-child><RouterLink :to="`/pay/${order.id}`">Pay now</RouterLink></Button>
          <Button v-if="canCancel" variant="outline" :disabled="cancelling" @click="cancel">Cancel order</Button>
        </div>
      </div>

      <div class="mt-6 grid gap-4 sm:grid-cols-2">
        <section class="rounded-2xl border bg-card p-5 text-sm">
          <h2 class="flex items-center gap-2 font-semibold"><MapPinIcon class="size-4 text-primary" /> Delivery address</h2>
          <p class="mt-2 font-medium">{{ order.ship_recipient }} · {{ order.ship_phone }}</p>
          <p class="text-muted-foreground">{{ order.ship_address }}</p>
        </section>
        <section class="rounded-2xl border bg-card p-5 text-sm">
          <h2 class="flex items-center gap-2 font-semibold"><CreditCardIcon class="size-4 text-primary" /> Payment</h2>
          <p class="mt-2 font-medium">{{ paymentLabels[order.payment_method] }}</p>
          <p :class="cn(order.payment_status === 'paid' ? 'text-[oklch(0.45_0.1_150)]' : order.payment_status === 'failed' ? 'text-destructive' : 'text-muted-foreground')">{{ paymentText }}</p>
        </section>
      </div>

      <section v-for="shop in order.shops" :key="shop.id" class="mt-4 rounded-2xl border bg-card">
        <header class="flex items-center justify-between gap-3 border-b px-5 py-3">
          <RouterLink v-if="shop.artisan" :to="`/artisans/${shop.artisan.slug}`" class="flex items-center gap-2 font-medium hover:text-primary"><StoreIcon class="size-4 text-primary" /> {{ shop.artisan.shop_name }}</RouterLink>
          <span class="text-xs text-muted-foreground">Parcel from this shop</span>
        </header>
        <div class="px-5 pt-5"><OrderTimeline :status="shop.status" :placed-at="order.created_at" :shipped-at="shop.shipped_at" :delivered-at="shop.delivered_at" /></div>
        <ul class="mt-4 divide-y border-t">
          <li v-for="item in shop.items" :key="item.id" class="px-5 py-3 text-sm">
            <div class="flex justify-between gap-4">
              <RouterLink v-if="item.product" :to="`/product/${item.product.slug}`" class="hover:text-primary">{{ item.qty }} × {{ item.product_name }}</RouterLink>
              <span v-else>{{ item.qty }} × {{ item.product_name }}</span>
              <span>{{ peso(item.unit_price * item.qty) }}</span>
            </div>
            <!-- Reviews open once this shop's parcel is delivered -->
            <template v-if="shop.status === 'delivered' && item.product_id">
              <p v-if="myReviews[item.id]" class="mt-2 flex items-center gap-2 text-xs text-muted-foreground">
                <span class="flex" :aria-label="`You rated it ${myReviews[item.id]!.rating} out of 5`">
                  <StarIcon v-for="n in 5" :key="n" :class="cn('size-3.5', n <= myReviews[item.id]!.rating ? 'fill-mango text-mango' : 'text-border')" />
                </span>
                Your review{{ myReviews[item.id]!.comment ? `: “${myReviews[item.id]!.comment}”` : '' }}
              </p>
              <ReviewForm
                v-else-if="reviewing === item.id"
                class="mt-3"
                :product-id="item.product_id"
                :order-item-id="item.id"
                :product-name="item.product_name"
                @saved="(r) => { myReviews[r.order_item_id] = r; reviewing = null }"
                @cancel="reviewing = null"
              />
              <button v-else class="mt-1 flex items-center gap-1 py-2 text-xs font-medium text-primary hover:underline" @click="reviewing = item.id">
                <StarIcon class="size-3.5" /> Write a review
              </button>
            </template>
          </li>
        </ul>
        <footer class="flex justify-between border-t px-5 py-3 text-sm text-muted-foreground">
          <span>Subtotal {{ peso(shop.subtotal) }} + shipping {{ peso(shop.shipping_fee) }}</span>
          <span class="font-medium text-foreground">{{ peso(Number(shop.subtotal) + Number(shop.shipping_fee)) }}</span>
        </footer>
      </section>

      <div class="mt-4 flex items-baseline justify-end gap-3 rounded-2xl bg-secondary p-5">
        <span class="text-sm text-muted-foreground">Order total</span>
        <span class="font-display text-3xl">{{ peso(order.total) }}</span>
      </div>
    </template>
  </div>
</template>
