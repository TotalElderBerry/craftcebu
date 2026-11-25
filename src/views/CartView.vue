<script setup lang="ts">
import { ShoppingBagIcon, StoreIcon, Trash2Icon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import EmptyState from '@/components/catalog/EmptyState.vue'
import QtyStepper from '@/components/QtyStepper.vue'
import { Button } from '@/components/ui/button'
import { fetchProductsByIds, fetchShippingFee } from '@/lib/catalog'
import { peso } from '@/lib/format'
import { isSupabaseConfigured } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useCartStore } from '@/stores/cart'

const cart = useCartStore()
const auth = useAuthStore()
const router = useRouter()
const shippingFee = ref(0)
const refreshing = ref(true)

onMounted(async () => {
  if (!isSupabaseConfigured) return
  try {
    await cart.whenLoaded()
    const [fresh, fee] = await Promise.all([fetchProductsByIds(cart.lines.map(l => l.productId)), fetchShippingFee()])
    shippingFee.value = fee
    const dropped = cart.refresh(fresh)
    if (dropped.length) toast.warning(`Removed from your cart because they're no longer available: ${dropped.join(', ')}`)
  }
  finally {
    refreshing.value = false
  }
})

const shipping = computed(() => cart.shops.length * shippingFee.value)
const total = computed(() => cart.subtotal + shipping.value)

function checkout() {
  router.push(auth.user ? '/checkout' : { name: 'login', query: { redirect: '/checkout' } })
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-10">
    <h1 class="font-display text-4xl font-medium sm:text-5xl">Your cart</h1>

    <EmptyState v-if="!cart.lines.length && !refreshing" class="mt-8" title="Walay sulod · Your cart is empty" body="Find something made by hand in Cebu.">
      <Button as-child><RouterLink to="/shop"><ShoppingBagIcon /> Shop the crafts</RouterLink></Button>
    </EmptyState>

    <div v-else-if="cart.lines.length" class="mt-8 grid items-start gap-8 lg:grid-cols-[1fr_340px]">
      <div class="grid gap-5">
        <section v-for="group in cart.shops" :key="group.artisan.id" class="rounded-2xl border bg-card">
          <header class="flex items-center justify-between gap-3 border-b px-5 py-3">
            <RouterLink :to="`/artisans/${group.artisan.slug}`" class="flex items-center gap-2 font-medium hover:text-primary">
              <StoreIcon class="size-4 text-primary" /> {{ group.artisan.shopName }}
            </RouterLink>
            <span class="text-xs text-muted-foreground">Ships separately</span>
          </header>
          <ul class="divide-y">
            <li v-for="line in group.lines" :key="line.productId" class="flex gap-4 p-5">
              <RouterLink :to="`/product/${line.slug}`" class="shrink-0">
                <img v-if="line.image" :src="line.image" :alt="line.name" class="size-24 rounded-lg object-cover">
                <div v-else class="size-24 rounded-lg bg-muted" />
              </RouterLink>
              <div class="flex min-w-0 flex-1 flex-col">
                <div class="flex items-start justify-between gap-3">
                  <RouterLink :to="`/product/${line.slug}`" class="font-medium hover:text-primary">{{ line.name }}</RouterLink>
                  <p class="font-display text-lg whitespace-nowrap">{{ peso(line.price * line.qty) }}</p>
                </div>
                <p class="text-sm text-muted-foreground">{{ peso(line.price) }} each<span v-if="line.stock <= 5"> · only {{ line.stock }} left</span></p>
                <div class="mt-auto flex items-center justify-between gap-3 pt-3">
                  <QtyStepper :model-value="line.qty" :max="line.stock" size="sm" @update:model-value="(q: number) => cart.setQty(line.productId, q)" />
                  <button class="flex items-center gap-1 text-sm text-muted-foreground hover:text-destructive" @click="cart.remove(line.productId)">
                    <Trash2Icon class="size-4" /> Remove
                  </button>
                </div>
              </div>
            </li>
          </ul>
          <footer class="flex justify-between border-t px-5 py-3 text-sm">
            <span class="text-muted-foreground">Shop subtotal</span>
            <span class="font-medium">{{ peso(group.subtotal) }}</span>
          </footer>
        </section>
      </div>

      <aside class="rounded-2xl border bg-card p-6 lg:sticky lg:top-24">
        <h2 class="font-display text-2xl font-medium">Summary</h2>
        <dl class="mt-5 grid gap-3 text-sm">
          <div class="flex justify-between"><dt class="text-muted-foreground">Items ({{ cart.count }})</dt><dd>{{ peso(cart.subtotal) }}</dd></div>
          <div class="flex justify-between">
            <dt class="text-muted-foreground">Shipping ({{ cart.shops.length }} {{ cart.shops.length === 1 ? 'shop' : 'shops' }} × {{ peso(shippingFee) }})</dt>
            <dd>{{ peso(shipping) }}</dd>
          </div>
          <div class="flex justify-between border-t pt-3 text-base font-semibold"><dt>Total</dt><dd class="font-display text-2xl">{{ peso(total) }}</dd></div>
        </dl>
        <Button size="lg" class="mt-6 w-full" :disabled="refreshing" @click="checkout">Check out</Button>
        <p class="mt-3 text-center text-xs text-muted-foreground">Pay with cash on delivery or online. Each shop ships its own parcel.</p>
      </aside>
    </div>
  </div>
</template>
