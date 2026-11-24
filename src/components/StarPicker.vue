<script setup lang="ts">
import { StarIcon } from '@lucide/vue'
import { ref } from 'vue'
import { cn } from '@/lib/utils'

const rating = defineModel<number>({ required: true })
const hover = ref(0)
const labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent']
</script>

<template>
  <div class="flex items-center gap-3">
    <div class="flex" role="radiogroup" aria-label="Rating" @mouseleave="hover = 0">
      <button
        v-for="n in 5"
        :key="n"
        type="button"
        role="radio"
        :aria-checked="rating === n"
        :aria-label="`${n} ${n === 1 ? 'star' : 'stars'}`"
        class="p-0.5"
        @mouseenter="hover = n"
        @click="rating = n"
      >
        <StarIcon :class="cn('size-6 transition-colors', n <= (hover || rating) ? 'fill-mango text-mango' : 'text-border')" />
      </button>
    </div>
    <span class="text-sm text-muted-foreground">{{ labels[hover || rating] }}</span>
  </div>
</template>
