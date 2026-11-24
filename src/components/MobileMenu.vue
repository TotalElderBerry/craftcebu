<script setup lang="ts">
import { HeartIcon, LayoutDashboardIcon, MenuIcon, PackageIcon, SearchIcon, StoreIcon, UserIcon } from '@lucide/vue'
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import HablonBand from '@/components/HablonBand.vue'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetDescription, SheetTitle, SheetTrigger } from '@/components/ui/sheet'
import { useAuthStore } from '@/stores/auth'

defineProps<{ links: { label: string, to: string }[] }>()

const auth = useAuthStore()
const router = useRouter()
const open = ref(false)
const search = ref('')

function go(to: string | object) {
  open.value = false
  router.push(to as string)
}

function submitSearch() {
  go({ path: '/shop', query: search.value.trim() ? { q: search.value.trim() } : {} })
  search.value = ''
}
</script>

<template>
  <Sheet v-model:open="open">
    <SheetTrigger as-child>
      <Button variant="ghost" size="icon" class="lg:hidden" aria-label="Open menu"><MenuIcon /></Button>
    </SheetTrigger>
    <SheetContent side="left" class="w-[85%] max-w-sm gap-0 bg-background p-0">
      <HablonBand />
      <div class="grid gap-6 p-6">
        <div>
          <SheetTitle class="font-display text-2xl font-semibold">Craft<span class="text-primary italic">Cebu</span></SheetTitle>
          <SheetDescription class="text-xs">Hinimo sa Sugbo · Handmade in Cebu</SheetDescription>
        </div>

        <form role="search" class="flex h-11 items-center gap-2 rounded-full border bg-card px-4 text-sm" @submit.prevent="submitSearch">
          <SearchIcon class="size-4 text-muted-foreground" />
          <input v-model="search" type="search" aria-label="Search crafts" placeholder="Search hablon, rattan, guitars…" class="w-full bg-transparent outline-none placeholder:text-muted-foreground">
        </form>

        <nav class="grid" aria-label="Main">
          <button v-for="l in links" :key="l.label" class="border-b py-3 text-left font-display text-xl" @click="go(l.to)">{{ l.label }}</button>
        </nav>

        <div v-if="auth.user" class="grid gap-1 text-sm">
          <button v-if="auth.isOwner" class="flex items-center gap-3 rounded-md px-2 py-2 hover:bg-secondary" @click="go('/admin')"><LayoutDashboardIcon class="size-4" /> Admin Centre</button>
          <button v-if="auth.isArtisan || auth.isOwner" class="flex items-center gap-3 rounded-md px-2 py-2 hover:bg-secondary" @click="go('/seller')"><StoreIcon class="size-4" /> Seller Centre</button>
          <button v-else class="flex items-center gap-3 rounded-md px-2 py-2 hover:bg-secondary" @click="go('/sell')"><StoreIcon class="size-4" /> Sell on CraftCebu</button>
          <button class="flex items-center gap-3 rounded-md px-2 py-2 hover:bg-secondary" @click="go('/orders')"><PackageIcon class="size-4" /> My purchases</button>
          <button class="flex items-center gap-3 rounded-md px-2 py-2 hover:bg-secondary" @click="go('/wishlist')"><HeartIcon class="size-4" /> Saved pieces</button>
          <button class="flex items-center gap-3 rounded-md px-2 py-2 hover:bg-secondary" @click="go('/account')"><UserIcon class="size-4" /> My account</button>
        </div>
        <div v-else class="grid gap-2">
          <Button @click="go('/login')">Log in</Button>
          <Button variant="outline" @click="go('/register')">Create an account</Button>
        </div>
      </div>
    </SheetContent>
  </Sheet>
</template>
