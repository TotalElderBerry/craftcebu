<script setup lang="ts">
import WovenMark from '@/components/WovenMark.vue'

defineProps<{ title: string, body?: string }>()
</script>

<template>
  <div class="flex flex-col items-center rounded-2xl border border-dashed px-6 py-16 text-center">
    <WovenMark class="size-10 opacity-80" />
    <h3 class="mt-4 font-display text-2xl font-medium">{{ title }}</h3>
    <p v-if="body" class="mt-2 max-w-sm text-sm text-muted-foreground">{{ body }}</p>
    <div v-if="$slots.default" class="mt-6"><slot /></div>
  </div>
</template>
