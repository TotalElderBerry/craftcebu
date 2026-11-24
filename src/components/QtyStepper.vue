<script setup lang="ts">
import { cn } from '@/lib/utils'

const props = withDefaults(defineProps<{ max: number, size?: 'sm' | 'lg', label?: string }>(), { size: 'lg', label: 'Quantity' })
const qty = defineModel<number>({ required: true })
</script>

<template>
  <div :class="cn('flex items-center rounded-full border bg-card', props.size === 'lg' ? 'h-12' : 'h-9')" role="group" :aria-label="label">
    <button type="button" :class="cn('h-full disabled:opacity-40', props.size === 'lg' ? 'px-4 text-lg' : 'px-3')" :disabled="qty <= 1" aria-label="Decrease quantity" @click="qty--">−</button>
    <span :class="cn('text-center tabular-nums', props.size === 'lg' ? 'w-8' : 'w-6 text-sm')" aria-live="polite">{{ qty }}</span>
    <button type="button" :class="cn('h-full disabled:opacity-40', props.size === 'lg' ? 'px-4 text-lg' : 'px-3')" :disabled="qty >= max" aria-label="Increase quantity" @click="qty++">+</button>
  </div>
</template>
