<script setup lang="ts">
import type { ShopArtisan } from '@/lib/catalog'
import { ArrowUpRightIcon, MapPinIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import EmptyState from '@/components/catalog/EmptyState.vue'
import VerifiedBadge from '@/components/catalog/VerifiedBadge.vue'
import { fetchArtisans } from '@/lib/catalog'
import { yearsInCraft } from '@/lib/format'
import { isSupabaseConfigured } from '@/lib/supabase'
import { cn } from '@/lib/utils'

const artisans = ref<ShopArtisan[]>([])
const loading = ref(true)
const town = ref<string | null>(null)

onMounted(async () => {
  try {
    if (isSupabaseConfigured) artisans.value = await fetchArtisans()
  }
  finally {
    loading.value = false
  }
})

const towns = computed(() => [...new Set(artisans.value.map(a => a.town?.name).filter(Boolean))] as string[])
const visible = computed(() => (town.value ? artisans.value.filter(a => a.town?.name === town.value) : artisans.value))
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-10">
    <header class="border-b pb-8">
      <p class="caps text-primary">Ang mga Artisan</p>
      <h1 class="mt-2 font-display text-4xl font-medium sm:text-5xl">Meet the makers</h1>
      <p class="mt-2 text-muted-foreground">Every shop here is run by a verified Cebuano artisan.</p>
      <div v-if="towns.length > 1" class="mt-6 flex flex-wrap gap-2">
        <button :class="cn('h-9 rounded-full border px-4 text-xs font-medium', !town ? 'border-foreground bg-foreground text-background' : 'hover:border-foreground')" @click="town = null">All towns</button>
        <button
          v-for="t in towns"
          :key="t"
          :class="cn('h-9 rounded-full border px-4 text-xs font-medium', town === t ? 'border-foreground bg-foreground text-background' : 'hover:border-foreground')"
          @click="town = t"
        >
          {{ t }}
        </button>
      </div>
    </header>

    <div v-if="loading" class="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <div v-for="n in 3" :key="n" class="h-56 animate-pulse rounded-2xl bg-muted" />
    </div>
    <EmptyState v-else-if="!visible.length" class="mt-8" title="No makers yet" body="Verified artisans will appear here once the owner approves their applications." />
    <div v-else class="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <article v-for="a in visible" :key="a.id" class="group relative flex flex-col rounded-2xl border bg-card p-6 transition-shadow hover:shadow-lg">
        <div class="flex items-center gap-4">
          <img v-if="a.photo_url" :src="a.photo_url" :alt="a.shop_name" class="size-16 rounded-full object-cover">
          <div v-else class="grid size-16 place-items-center rounded-full bg-primary font-display text-2xl text-primary-foreground">{{ a.shop_name[0] }}</div>
          <div class="min-w-0">
            <h2 class="flex items-center gap-1.5 font-display text-xl font-medium">
              <RouterLink :to="`/artisans/${a.slug}`" class="truncate after:absolute after:inset-0">{{ a.shop_name }}</RouterLink>
              <VerifiedBadge compact />
            </h2>
            <p v-if="a.town" class="mt-0.5 flex items-center gap-1 text-sm text-muted-foreground"><MapPinIcon class="size-3.5" /> {{ a.town.name }}</p>
          </div>
        </div>
        <p class="mt-4 line-clamp-3 flex-1 text-sm leading-relaxed text-muted-foreground">{{ a.story }}</p>
        <div class="mt-5 flex items-center justify-between border-t pt-4 text-sm">
          <span class="text-muted-foreground">{{ yearsInCraft(a.craft_since) ? `${yearsInCraft(a.craft_since)} years in the craft` : 'New shop' }}</span>
          <ArrowUpRightIcon class="size-4 transition-colors group-hover:text-primary" />
        </div>
      </article>
    </div>
  </div>
</template>
