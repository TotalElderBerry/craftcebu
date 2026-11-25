<script setup lang="ts">
import type { AddressInput } from '@/lib/orders'
import type { Address, PaymentMethod } from '@/types/database'
import { BanknoteIcon, CreditCardIcon, MapPinIcon, PlusIcon, SmartphoneIcon, StoreIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AddressForm from '@/components/AddressForm.vue'
import { Button } from '@/components/ui/button'
import { removedNotice } from '@/lib/cartMerge'
import { fetchProductsByIds, fetchShippingFee } from '@/lib/catalog'
import { peso } from '@/lib/format'
import { addAddress, fetchAddresses, placeOrder, startMayaCheckout } from '@/lib/orders'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'
import { useCartStore } from '@/stores/cart'

const cart = useCartStore()
const auth = useAuthStore()
const router = useRouter()

const addresses = ref<Address[]>([])
const addressId = ref<string | null>(null)
const addingAddress = ref(false)
const savingAddress = ref(false)
const shippingFee = ref(0)
const method = ref<PaymentMethod>('cod')
const placing = ref(false)
const loading = ref(true)

onMounted(async () => {
  // A signed-in cart loads from the database (right after signing in, it may
  // still be merging the guest cart), so wait before deciding it is empty.
  await cart.whenLoaded()
  if (!cart.lines.length) {
    router.replace('/cart')
    return
  }
  try {
    const [list, fee, fresh] = await Promise.all([
      fetchAddresses(auth.user!.id),
      fetchShippingFee(),
      fetchProductsByIds(cart.lines.map(l => l.productId)),
    ])
    addresses.value = list
    addressId.value = list[0]?.id ?? null
    addingAddress.value = !list.length
    shippingFee.value = fee
    const notice = removedNotice(cart.refresh(fresh), cart.takeHiddenRemoved())
    if (notice) toast.warning(notice)
  }
  finally {
    loading.value = false
  }
})

async function saveAddress(input: AddressInput, makeDefault: boolean) {
  savingAddress.value = true
  try {
    const created = await addAddress(auth.user!.id, input, makeDefault || !addresses.value.length)
    addresses.value = [created, ...addresses.value.map(a => ({ ...a, is_default: created.is_default ? false : a.is_default }))]
    addressId.value = created.id
    addingAddress.value = false
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save the address')
  }
  finally {
    savingAddress.value = false
  }
}

const shipping = computed(() => cart.shops.length * shippingFee.value)
const total = computed(() => cart.subtotal + shipping.value)

const methods: { key: PaymentMethod, label: string, body: string, icon: typeof BanknoteIcon, disabled?: boolean }[] = [
  { key: 'cod', label: 'Cash on delivery', body: 'Pay each shop\'s courier when your parcel arrives.', icon: BanknoteIcon },
  { key: 'maya', label: 'Maya', body: 'Pay with your Maya wallet or a card on Maya\'s secure page (sandbox).', icon: SmartphoneIcon },
  { key: 'mock', label: 'Demo online payment', body: 'A practice payment page for the capstone demo. No real money moves.', icon: CreditCardIcon },
]

async function submit() {
  if (!addressId.value) {
    toast.error('Add a delivery address first.')
    return
  }
  placing.value = true
  const purchased = cart.lines.map(l => l.productId)
  try {
    const orderId = await placeOrder(cart.lines.map(l => ({ product_id: l.productId, qty: l.qty })), addressId.value, method.value)
    cart.removeMany(purchased)
    if (method.value === 'maya') {
      try {
        window.location.href = await startMayaCheckout(orderId)
        return
      }
      catch (e) {
        // The order exists and holds its stock; the buyer can retry from it.
        toast.error(`Couldn't open Maya: ${(e as Error).message}. You can try again from your order.`)
        router.replace(`/orders/${orderId}`)
        return
      }
    }
    if (method.value === 'mock') router.replace(`/pay/${orderId}`)
    else router.replace({ path: `/orders/${orderId}`, query: { placed: '1' } })
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not place your order')
  }
  finally {
    placing.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-10">
    <h1 class="font-display text-4xl font-medium sm:text-5xl">Checkout</h1>

    <div v-if="loading" class="mt-8 h-96 animate-pulse rounded-2xl bg-muted" />

    <div v-else class="mt-8 grid items-start gap-8 lg:grid-cols-[1fr_360px]">
      <div class="grid gap-5">
        <!-- Address -->
        <section class="rounded-2xl border bg-card p-6">
          <h2 class="flex items-center gap-2 font-display text-2xl font-medium"><MapPinIcon class="size-5 text-primary" /> Delivery address</h2>
          <div v-if="addresses.length && !addingAddress" class="mt-4 grid gap-3">
            <label
              v-for="a in addresses"
              :key="a.id"
              :class="cn('flex cursor-pointer gap-3 rounded-xl border p-4 transition-colors', addressId === a.id ? 'border-primary bg-primary/5' : 'hover:border-foreground/30')"
            >
              <input v-model="addressId" type="radio" name="address" :value="a.id" class="mt-1 size-4 accent-[var(--primary)]">
              <span class="text-sm">
                <span class="font-semibold">{{ a.recipient }}</span> <span class="text-muted-foreground">· {{ a.phone }}</span>
                <span v-if="a.is_default" class="ml-2 rounded-full bg-mango/40 px-2 py-0.5 text-xs font-medium">Default</span>
                <span class="mt-1 block text-muted-foreground">{{ a.street }}, {{ a.barangay }}, {{ a.city }}, {{ a.province }}</span>
              </span>
            </label>
            <button class="flex items-center gap-1.5 justify-self-start text-sm font-medium text-primary hover:underline" @click="addingAddress = true">
              <PlusIcon class="size-4" /> Add a new address
            </button>
          </div>
          <div v-else class="mt-4">
            <AddressForm :saving="savingAddress" :cancellable="addresses.length > 0" @submit="saveAddress" @cancel="addingAddress = false" />
          </div>
        </section>

        <!-- Payment -->
        <section class="rounded-2xl border bg-card p-6">
          <h2 class="font-display text-2xl font-medium">Payment</h2>
          <div class="mt-4 grid gap-3">
            <label
              v-for="m in methods"
              :key="m.key"
              :class="cn('flex gap-3 rounded-xl border p-4 transition-colors', m.disabled ? 'cursor-not-allowed opacity-55' : 'cursor-pointer', method === m.key ? 'border-primary bg-primary/5' : !m.disabled && 'hover:border-foreground/30')"
            >
              <input v-model="method" type="radio" name="method" :value="m.key" :disabled="m.disabled" class="mt-1 size-4 accent-[var(--primary)]">
              <component :is="m.icon" class="mt-0.5 size-5 shrink-0 text-primary" />
              <span class="text-sm">
                <span class="font-semibold">{{ m.label }}</span>
                <span class="mt-0.5 block text-muted-foreground">{{ m.body }}</span>
              </span>
            </label>
          </div>
        </section>
      </div>

      <!-- Summary -->
      <aside class="rounded-2xl border bg-card p-6 lg:sticky lg:top-24">
        <h2 class="font-display text-2xl font-medium">Your order</h2>
        <div class="mt-4 grid gap-4">
          <div v-for="group in cart.shops" :key="group.artisan.id" class="rounded-xl bg-secondary p-4">
            <p class="flex items-center gap-1.5 text-sm font-semibold"><StoreIcon class="size-4 text-primary" /> {{ group.artisan.shopName }}</p>
            <ul class="mt-2 grid gap-1.5 text-sm">
              <li v-for="l in group.lines" :key="l.productId" class="flex justify-between gap-3">
                <span class="truncate">{{ l.qty }} × {{ l.name }}</span>
                <span class="shrink-0">{{ peso(l.price * l.qty) }}</span>
              </li>
              <li class="flex justify-between gap-3 text-muted-foreground"><span>Shipping</span><span>{{ peso(shippingFee) }}</span></li>
            </ul>
          </div>
        </div>
        <dl class="mt-5 grid gap-2 border-t pt-4 text-sm">
          <div class="flex justify-between"><dt class="text-muted-foreground">Items</dt><dd>{{ peso(cart.subtotal) }}</dd></div>
          <div class="flex justify-between"><dt class="text-muted-foreground">Shipping</dt><dd>{{ peso(shipping) }}</dd></div>
          <div class="flex items-baseline justify-between pt-2 font-semibold"><dt>Total</dt><dd class="font-display text-2xl">{{ peso(total) }}</dd></div>
        </dl>
        <Button size="lg" class="mt-6 w-full" :disabled="placing || !cart.lines.length || !addressId" @click="submit">
          {{ placing ? 'Placing order…' : method === 'maya' ? 'Continue to Maya' : method === 'mock' ? 'Continue to payment' : 'Place order' }}
        </Button>
        <p class="mt-3 text-center text-xs text-muted-foreground">Prices and stock are checked again when you place the order.</p>
      </aside>
    </div>
  </div>
</template>
