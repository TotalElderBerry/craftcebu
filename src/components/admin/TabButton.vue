<script setup lang="ts">
import { cn } from '@/lib/utils'

defineProps<{ active: boolean, count?: number }>()
defineEmits<{ select: [] }>()
</script>

<template>
  <button
    role="tab"
    :aria-selected="active"
    :class="cn('-mb-px shrink-0 border-b-2 pb-3 font-medium transition-colors', active ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground')"
    @click="$emit('select')"
  >
    <slot /><span v-if="count !== undefined" class="ml-1 tabular-nums">({{ count }})</span>
  </button>
</template>
