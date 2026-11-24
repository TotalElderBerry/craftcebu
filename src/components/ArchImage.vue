<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{ src: string, alt: string, class?: HTMLAttributes['class'] }>()
</script>

<template>
  <div :class="cn('arch bg-muted', props.class)">
    <img :src="src" :alt="alt" loading="lazy" class="size-full object-cover">
  </div>
</template>
