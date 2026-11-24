<script setup lang="ts">
import StampBadge from '@/components/StampBadge.vue'
import { images } from '@/lib/images'

defineProps<{ title: string, description?: string }>()
</script>

<template>
  <div class="mx-auto grid max-w-6xl items-center gap-12 px-4 py-12 lg:grid-cols-2 lg:py-16">
    <div class="relative hidden lg:block">
      <div class="relative overflow-hidden rounded-2xl">
        <img :src="images.weavingHands" alt="An artisan's hands weaving dried straw" class="aspect-[4/5] max-h-[600px] w-full object-cover">
        <div class="hablon-v absolute inset-y-0 left-0 w-3" />
        <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-8 pt-24 text-white">
          <p class="caps text-mango">Hinimo sa Sugbo</p>
          <p class="mt-2 max-w-xs font-display text-2xl leading-snug">Every piece is sold by the hands that made it.</p>
        </div>
      </div>
      <StampBadge class="absolute -top-6 -right-6" />
    </div>

    <div class="mx-auto w-full max-w-sm">
      <h1 class="font-display text-4xl font-medium sm:text-5xl">{{ title }}</h1>
      <p v-if="description" class="mt-3 text-muted-foreground">{{ description }}</p>
      <div class="mt-8">
        <slot />
      </div>
      <p v-if="$slots.footer" class="mt-8 border-t pt-6 text-sm text-muted-foreground">
        <slot name="footer" />
      </p>
    </div>
  </div>
</template>
