<script setup lang="ts">
import { CheckCircle2Icon, ClockIcon, Loader2Icon, XCircleIcon } from '@lucide/vue'
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { shortId, startMayaCheckout, verifyMayaPayment } from '@/lib/orders'

// Maya sends the buyer here with ?order=…&result=success|failure|cancel.
// The result in the URL is only a hint; the order changes only after the
// server confirms the payment with Maya.
const route = useRoute()
const router = useRouter()
const orderId = typeof route.query.order === 'string' ? route.query.order : ''
const hint = route.query.result
const state = ref<'checking' | 'paid' | 'failed' | 'pending' | 'error'>('checking')
const message = ref('')
const retrying = ref(false)

async function check() {
  state.value = 'checking'
  try {
    const { paymentStatus } = await verifyMayaPayment(orderId)
    state.value = paymentStatus === 'paid' ? 'paid' : paymentStatus === 'failed' ? 'failed' : 'pending'
    if (state.value === 'paid') setTimeout(() => router.replace({ path: `/orders/${orderId}`, query: { placed: '1' } }), 1500)
  }
  catch (e) {
    state.value = 'error'
    message.value = (e as Error).message
  }
}

async function retry() {
  retrying.value = true
  try {
    window.location.href = await startMayaCheckout(orderId)
  }
  catch (e) {
    toast.error((e as Error).message)
    retrying.value = false
  }
}

onMounted(() => (orderId ? check() : (state.value = 'error', message.value = 'Missing order.')))
</script>

<template>
  <div class="mx-auto max-w-md px-4 py-20 text-center">
    <template v-if="state === 'checking'">
      <Loader2Icon class="mx-auto size-10 animate-spin text-primary" />
      <h1 class="mt-6 font-display text-3xl font-medium">Checking your payment…</h1>
      <p class="mt-2 text-muted-foreground">We're confirming with Maya. This takes a few seconds.</p>
    </template>

    <template v-else-if="state === 'paid'">
      <CheckCircle2Icon class="mx-auto size-12 text-[oklch(0.5_0.12_150)]" />
      <h1 class="mt-6 font-display text-3xl font-medium">Payment received. Salamat!</h1>
      <p class="mt-2 text-muted-foreground">Taking you to order {{ shortId(orderId) }}…</p>
    </template>

    <template v-else-if="state === 'failed'">
      <XCircleIcon class="mx-auto size-12 text-destructive" />
      <h1 class="mt-6 font-display text-3xl font-medium">The payment didn't go through</h1>
      <p class="mt-2 text-muted-foreground">Nothing was charged. Your order was cancelled and the pieces went back to the shops.</p>
      <Button as-child class="mt-8"><RouterLink to="/cart">Back to your cart</RouterLink></Button>
    </template>

    <template v-else-if="state === 'pending'">
      <ClockIcon class="mx-auto size-12 text-primary" />
      <h1 class="mt-6 font-display text-3xl font-medium">{{ hint === 'cancel' ? 'You left the payment page' : 'Payment not finished yet' }}</h1>
      <p class="mt-2 text-muted-foreground">Order {{ shortId(orderId) }} is waiting for payment. We'll hold the pieces for about an hour.</p>
      <div class="mt-8 flex flex-col gap-2">
        <Button :disabled="retrying" @click="retry">{{ retrying ? 'Opening Maya…' : 'Pay with Maya' }}</Button>
        <Button variant="outline" @click="check">Check again</Button>
        <Button as-child variant="ghost"><RouterLink :to="`/orders/${orderId}`">View order</RouterLink></Button>
      </div>
    </template>

    <template v-else>
      <XCircleIcon class="mx-auto size-12 text-destructive" />
      <h1 class="mt-6 font-display text-3xl font-medium">We couldn't check the payment</h1>
      <p class="mt-2 text-sm text-muted-foreground">{{ message }}</p>
      <div class="mt-8 flex flex-col gap-2">
        <Button @click="check">Try again</Button>
        <Button v-if="orderId" as-child variant="ghost"><RouterLink :to="`/orders/${orderId}`">View order</RouterLink></Button>
      </div>
    </template>
  </div>
</template>
