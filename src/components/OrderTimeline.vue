<script setup lang="ts">
import type { ShopOrderStatus } from '@/types/database'
import { CheckIcon, XIcon } from '@lucide/vue'
import { computed } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{ status: ShopOrderStatus, placedAt: string, shippedAt: string | null, deliveredAt: string | null }>()

const steps = computed(() => [
  { label: 'Placed', at: props.placedAt, done: true },
  { label: 'Shipped', at: props.shippedAt, done: props.status === 'shipped' || props.status === 'delivered' },
  { label: 'Delivered', at: props.deliveredAt, done: props.status === 'delivered' },
])
const when = (iso: string | null) => iso ? new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) : ''
</script>

<template>
  <p v-if="status === 'cancelled'" class="flex items-center gap-2 text-sm font-medium text-destructive"><XIcon class="size-4" /> Cancelled</p>
  <ol v-else class="flex items-start" aria-label="Delivery progress">
    <li v-for="(s, i) in steps" :key="s.label" class="relative flex flex-1 flex-col items-center text-center">
      <span v-if="i > 0" :class="cn('absolute top-3 right-1/2 h-0.5 w-full', s.done ? 'bg-primary' : 'bg-border')" aria-hidden="true" />
      <span :class="cn('relative grid size-6 place-items-center rounded-full border-2', s.done ? 'border-primary bg-primary text-primary-foreground' : 'border-border bg-card')">
        <CheckIcon v-if="s.done" class="size-3.5" />
      </span>
      <span :class="cn('mt-1.5 text-xs', s.done ? 'font-semibold' : 'text-muted-foreground')">{{ s.label }}</span>
      <span class="text-[0.7rem] text-muted-foreground">{{ when(s.at) }}</span>
    </li>
  </ol>
</template>
