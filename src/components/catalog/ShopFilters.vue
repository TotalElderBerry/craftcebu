<script setup lang="ts">
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/utils'

// The craft, town and price filters; shown in the sidebar on desktop and in a
// bottom sheet on phones.
defineProps<{
  categories: { slug: string, name: string }[]
  towns: { id: number, name: string }[]
  category?: string
  town?: string
}>()
const emit = defineEmits<{ set: [patch: Record<string, string | undefined>], applyPrice: [] }>()
const minPrice = defineModel<string>('min', { required: true })
const maxPrice = defineModel<string>('max', { required: true })
</script>

<template>
  <div class="grid gap-8">
    <section>
      <h2 class="caps text-muted-foreground">Craft</h2>
      <ul class="mt-3 grid gap-1 text-sm">
        <li>
          <button :class="cn('w-full rounded-md px-3 py-2.5 text-left hover:bg-secondary lg:py-1.5', !category && 'bg-secondary font-semibold')" @click="emit('set', { category: undefined })">All crafts</button>
        </li>
        <li v-for="c in categories" :key="c.slug">
          <button :class="cn('w-full rounded-md px-3 py-2.5 text-left hover:bg-secondary lg:py-1.5', category === c.slug && 'bg-secondary font-semibold text-primary')" @click="emit('set', { category: c.slug })">{{ c.name }}</button>
        </li>
      </ul>
    </section>

    <section>
      <h2 class="caps text-muted-foreground">Town</h2>
      <div class="mt-3 flex flex-wrap gap-2">
        <button
          v-for="t in towns"
          :key="t.id"
          :aria-pressed="town === t.name"
          :class="cn('h-10 rounded-full border px-4 text-sm font-medium transition-colors lg:h-8 lg:px-3 lg:text-xs', town === t.name ? 'border-primary bg-primary text-primary-foreground' : 'hover:border-foreground')"
          @click="emit('set', { town: town === t.name ? undefined : t.name })"
        >
          {{ t.name }}
        </button>
      </div>
    </section>

    <section>
      <h2 class="caps text-muted-foreground">Price (₱)</h2>
      <form class="mt-3 flex items-center gap-2" @submit.prevent="emit('applyPrice')">
        <Input v-model="minPrice" type="number" inputmode="numeric" min="0" placeholder="Min" aria-label="Minimum price" class="h-11 lg:h-9" />
        <span class="text-muted-foreground">–</span>
        <Input v-model="maxPrice" type="number" inputmode="numeric" min="0" placeholder="Max" aria-label="Maximum price" class="h-11 lg:h-9" />
        <Button type="submit" size="sm" variant="outline" class="h-11 shrink-0 px-4 lg:h-9 lg:px-3">Go</Button>
      </form>
    </section>
  </div>
</template>
