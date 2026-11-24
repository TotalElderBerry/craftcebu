<script setup lang="ts">
import WovenMark from '@/components/WovenMark.vue'

defineProps<{ to?: string, light?: boolean }>()
</script>

<template>
  <RouterLink :to="to ?? '/'" class="flex items-center gap-2.5" aria-label="CraftCebu home">
    <WovenMark class="size-8" />
    <span class="font-display text-[1.35rem] leading-none font-semibold tracking-tight">Craft<span :class="light ? 'text-mango italic' : 'text-primary italic'">Cebu</span></span>
  </RouterLink>
</template>
