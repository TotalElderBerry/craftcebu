<script setup lang="ts">
import { HeartIcon, HomeIcon, MapIcon, ShoppingBagIcon, StoreIcon } from '@lucide/vue'
import { useRoute } from 'vue-router'
import { cn } from '@/lib/utils'
import { useCartStore } from '@/stores/cart'

// App-style bottom navigation for phones (and the WebView app).
const route = useRoute()
const cart = useCartStore()

const tabs = [
  { label: 'Home', to: '/', icon: HomeIcon, match: (p: string) => p === '/' },
  { label: 'Shop', to: '/shop', icon: StoreIcon, match: (p: string) => p.startsWith('/shop') || p.startsWith('/artisans') },
  { label: 'Towns', to: '/origins', icon: MapIcon, match: (p: string) => p.startsWith('/origins') },
  { label: 'Saved', to: '/wishlist', icon: HeartIcon, match: (p: string) => p.startsWith('/wishlist') },
  { label: 'Cart', to: '/cart', icon: ShoppingBagIcon, match: (p: string) => p.startsWith('/cart') },
]
</script>

<template>
  <nav class="pb-safe fixed inset-x-0 bottom-0 z-40 border-t bg-background/95 backdrop-blur md:hidden" aria-label="App">
    <ul class="grid grid-cols-5">
      <li v-for="t in tabs" :key="t.label">
        <RouterLink
          :to="t.to"
          :aria-current="t.match(route.path) ? 'page' : undefined"
          :class="cn('relative flex h-16 flex-col items-center justify-center gap-1 text-[0.7rem] font-medium transition-colors', t.match(route.path) ? 'text-primary' : 'text-muted-foreground')"
        >
          <span v-if="t.match(route.path)" class="absolute top-0 h-0.5 w-8 rounded-full bg-primary" aria-hidden="true" />
          <span class="relative">
            <component :is="t.icon" :class="cn('size-5', t.match(route.path) && t.label === 'Saved' && 'fill-primary')" />
            <span v-if="t.label === 'Cart' && cart.count" class="absolute -top-1.5 -right-2.5 grid min-w-4 place-items-center rounded-full bg-mango px-1 text-[0.6rem] font-bold text-ink">{{ cart.count > 99 ? '99+' : cart.count }}</span>
          </span>
          {{ t.label }}
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>
