<script setup lang="ts">
import { ArrowRightIcon } from '@lucide/vue'
import { ref } from 'vue'
import { toast } from 'vue-sonner'
import HablonBand from '@/components/HablonBand.vue'
import WovenMark from '@/components/WovenMark.vue'

const email = ref('')

function subscribe() {
  // Newsletter storage isn't part of version 1; acknowledge for the demo.
  toast.success('Salamat! We\'ll tell you when new crafts arrive.')
  email.value = ''
}

const columns = [
  { title: 'Shop', links: [{ label: 'All crafts', to: '/shop' }, { label: 'Shop by town', to: '/origins' }, { label: 'Meet the makers', to: '/artisans' }] },
  { title: 'Sell', links: [{ label: 'Open a shop', to: '/sell' }, { label: 'Seller Centre', to: '/seller' }, { label: 'How it works', to: '/#how' }] },
  { title: 'Help', links: [{ label: 'FAQ', to: '/#faq' }, { label: 'My account', to: '/account' }, { label: 'hello@craftcebu.test', to: '/#faq' }] },
]
</script>

<template>
  <footer class="bg-ink text-[oklch(0.92_0.01_80)]">
    <HablonBand />
    <div class="mx-auto max-w-6xl px-4">
      <div class="grid gap-12 py-16 lg:grid-cols-[1.3fr_2fr]">
        <div>
          <div class="flex items-center gap-2.5">
            <WovenMark class="size-8" />
            <span class="font-display text-xl font-semibold">Craft<span class="text-mango italic">Cebu</span></span>
          </div>
          <p class="mt-4 max-w-xs text-sm leading-relaxed opacity-70">
            Hablon, rattan, guitars and shell craft, sold by the Cebuano hands that made them.
          </p>
          <form class="mt-8 flex max-w-sm items-center border-b border-white/30 pb-2" @submit.prevent="subscribe">
            <label for="footer-email" class="sr-only">Email address</label>
            <input id="footer-email" v-model="email" type="email" required placeholder="Get new-craft alerts by email" class="w-full bg-transparent text-sm outline-none placeholder:text-white/50">
            <button type="submit" aria-label="Subscribe" class="-my-2 grid size-10 place-items-center"><ArrowRightIcon class="size-4" /></button>
          </form>
        </div>
        <div class="grid gap-10 sm:grid-cols-3">
          <div v-for="col in columns" :key="col.title">
            <h3 class="caps text-mango">{{ col.title }}</h3>
            <ul class="mt-3 grid gap-1 text-sm">
              <li v-for="link in col.links" :key="link.label">
                <RouterLink :to="link.to" class="inline-block py-1.5 opacity-75 hover:opacity-100">{{ link.label }}</RouterLink>
              </li>
            </ul>
          </div>
        </div>
      </div>
      <div class="pb-safe-4 flex flex-col gap-2 border-t border-white/15 pt-6 text-xs opacity-60 sm:flex-row sm:justify-between sm:pb-6">
        <p>© {{ new Date().getFullYear() }} CraftCebu · Hinimo sa Sugbo</p>
        <p>Suportahi ang lokal</p>
      </div>
    </div>
  </footer>
</template>
