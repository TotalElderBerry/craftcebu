<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { BadgeCheckIcon } from '@lucide/vue'
import { cn } from '@/lib/utils'

// Circular stamp with text running around its edge; slowly turns.
const props = defineProps<{ text?: string, class?: HTMLAttributes['class'] }>()
const id = `stamp-${Math.random().toString(36).slice(2, 8)}`
</script>

<template>
  <div :class="cn('relative grid size-28 place-items-center rounded-full bg-mango text-ink', props.class)">
    <svg viewBox="0 0 100 100" class="absolute inset-0 size-full animate-[spin_24s_linear_infinite] motion-reduce:animate-none" aria-hidden="true">
      <defs><path :id="id" d="M50 50m-38 0a38 38 0 1 1 76 0a38 38 0 1 1-76 0" /></defs>
      <text font-size="9" font-weight="600" fill="currentColor">
        <!-- textLength stretches the words to the circle, leaving a small gap at the seam -->
        <textPath :href="`#${id}`" textLength="226" lengthAdjust="spacing">{{ props.text ?? 'VERIFIED CEBUANO ARTISAN · SUGBO ·' }}</textPath>
      </text>
    </svg>
    <BadgeCheckIcon class="size-8" />
  </div>
</template>
