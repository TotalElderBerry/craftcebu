<script setup lang="ts">
import type { OrderRow } from '@/lib/orders'
import { CreditCardIcon, ShieldCheckIcon } from '@lucide/vue'
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { peso } from '@/lib/format'
import { fetchOrder, mockPay, shortId } from '@/lib/orders'

// Stand-in for an online payment page, so the paid flow can be demonstrated
// before the Maya sandbox is wired up (Milestone 5).
const route = useRoute()
const router = useRouter()
const order = ref<OrderRow | null>(null)
const loading = ref(true)
const busy = ref(false)
const id = route.params.id as string

onMounted(async () => {
  try {
    order.value = await fetchOrder(id)
  }
  finally {
    loading.value = false
  }
})

async function pay(success: boolean) {
  busy.value = true
  try {
    await mockPay(id, success)
    if (success) toast.success('Payment received. Salamat!')
    else toast.error('Payment failed. Your order was cancelled and nothing was charged.')
    router.replace({ path: `/orders/${id}`, query: success ? { placed: '1' } : {} })
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Payment could not be completed')
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-md px-4 py-16">
    <div v-if="loading" class="h-80 animate-pulse rounded-2xl bg-muted" />
    <div v-else-if="!order" class="text-center text-muted-foreground">Order not found.</div>
    <div v-else-if="order.payment_method !== 'mock' || order.payment_status !== 'unpaid'" class="text-center">
      <p class="text-muted-foreground">This order doesn't need payment here.</p>
      <Button as-child class="mt-4"><RouterLink :to="`/orders/${id}`">View order</RouterLink></Button>
    </div>
    <div v-else class="overflow-hidden rounded-2xl border bg-card shadow-sm">
      <div class="hablon h-2" />
      <div class="p-8 text-center">
        <span class="inline-flex items-center gap-1.5 rounded-full bg-mango/40 px-3 py-1 text-xs font-semibold">Demo payment · no real money</span>
        <CreditCardIcon class="mx-auto mt-6 size-10 text-primary" />
        <p class="mt-4 text-sm text-muted-foreground">Order {{ shortId(order.id) }}</p>
        <p class="font-display text-5xl">{{ peso(order.total) }}</p>
        <div class="mt-8 grid gap-3">
          <Button size="lg" :disabled="busy" @click="pay(true)">Pay {{ peso(order.total) }}</Button>
          <Button size="lg" variant="outline" :disabled="busy" @click="pay(false)">Simulate a failed payment</Button>
        </div>
        <p class="mt-6 flex items-center justify-center gap-1.5 text-xs text-muted-foreground"><ShieldCheckIcon class="size-3.5" /> Real payments arrive with Maya in Milestone 5.</p>
      </div>
    </div>
  </div>
</template>
