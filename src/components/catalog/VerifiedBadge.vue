<script setup lang="ts">
import { BadgeCheckIcon } from '@lucide/vue'

defineProps<{ compact?: boolean }>()
</script>

<template>
  <span v-if="compact" class="inline-flex text-primary" title="Verified Cebuano Artisan" aria-label="Verified Cebuano Artisan">
    <BadgeCheckIcon class="size-4" />
  </span>
  <span v-else class="inline-flex items-center gap-1.5 rounded-full bg-mango px-3 py-1 text-xs font-semibold text-ink">
    <BadgeCheckIcon class="size-3.5 text-primary" /> Verified Cebuano Artisan
  </span>
</template>
