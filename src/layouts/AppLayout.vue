<script setup lang="ts">
import { SearchIcon, ShoppingBagIcon } from '@lucide/vue'
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import BrandLogo from '@/components/BrandLogo.vue'
import MobileMenu from '@/components/MobileMenu.vue'
import SetupNotice from '@/components/SetupNotice.vue'
import SiteFooter from '@/components/SiteFooter.vue'
import { Button } from '@/components/ui/button'
import UserMenu from '@/components/UserMenu.vue'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'
import { useCartStore } from '@/stores/cart'

const auth = useAuthStore()
const cart = useCartStore()
const route = useRoute()
const router = useRouter()
const search = ref('')

function submitSearch() {
  router.push({ path: '/shop', query: search.value.trim() ? { q: search.value.trim() } : {} })
  search.value = ''
}

// On the home page the header floats over the clay hero in light text.
const overHero = computed(() => route.name === 'home')

const links = [
  { label: 'Shop', to: '/shop' },
  { label: 'Towns', to: '/origins' },
  { label: 'Makers', to: '/artisans' },
  { label: 'Help', to: '/#faq' },
]
</script>

<template>
  <div class="flex min-h-svh flex-col">
    <SetupNotice />
    <header :class="cn('pt-safe z-40 w-full', overHero ? 'absolute inset-x-0 text-[oklch(0.97_0.012_80)]' : 'sticky top-0 border-b bg-background/95 backdrop-blur')">
      <div :class="cn('mx-auto flex max-w-6xl items-center gap-6 px-4', overHero ? 'h-20 px-6' : 'h-16')">
        <div class="flex items-center gap-1">
          <MobileMenu :links="links" />
          <BrandLogo :light="overHero" />
        </div>
        <nav class="hidden items-center gap-6 text-sm font-medium lg:flex" aria-label="Main">
          <RouterLink v-for="l in links" :key="l.label" :to="l.to" class="opacity-70 transition-opacity hover:opacity-100">
            {{ l.label }}
          </RouterLink>
        </nav>
        <form role="search" :class="cn('ml-auto hidden h-10 max-w-xs flex-1 items-center gap-2 rounded-full border px-4 text-sm md:flex', overHero ? 'border-white/25 bg-white/10 text-white/70' : 'bg-card text-muted-foreground')" @submit.prevent="submitSearch">
          <SearchIcon class="size-4" />
          <input v-model="search" type="search" aria-label="Search crafts" class="w-full bg-transparent outline-none placeholder:text-current" placeholder="Search hablon, rattan, guitars…">
        </form>
        <div class="ml-auto flex items-center gap-1 md:ml-0">
          <Button variant="ghost" size="icon" as-child class="relative">
            <RouterLink to="/cart" :aria-label="`Cart, ${cart.count} items`">
              <ShoppingBagIcon />
              <span v-if="cart.count" class="absolute -top-0.5 -right-0.5 grid min-w-5 place-items-center rounded-full bg-mango px-1 text-[0.65rem] font-bold text-ink">{{ cart.count > 99 ? '99+' : cart.count }}</span>
            </RouterLink>
          </Button>
          <UserMenu v-if="auth.user" />
          <Button v-else as-child size="sm" class="h-10 rounded-full px-4"><RouterLink to="/login">Log in</RouterLink></Button>
        </div>
      </div>
    </header>

    <main class="flex-1">
      <RouterView />
    </main>

    <SiteFooter />
  </div>
</template>
