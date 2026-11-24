<script setup lang="ts">
// The white panel every Admin and Seller Centre page sits in.
defineProps<{ title: string, subtitle?: string }>()
</script>

<template>
  <section class="rounded-lg border bg-card">
    <div class="flex flex-wrap items-start justify-between gap-3 px-5 pt-5">
      <div>
        <h1 class="text-lg font-semibold">{{ title }}</h1>
        <p v-if="subtitle" class="text-sm text-muted-foreground">{{ subtitle }}</p>
      </div>
      <div v-if="$slots.actions" class="flex w-full flex-wrap items-center gap-2 sm:w-auto [&>*]:flex-1 sm:[&>*]:flex-none"><slot name="actions" /></div>
    </div>
    <div v-if="$slots.tabs" class="mt-4 flex gap-6 overflow-x-auto border-b px-5 text-sm" role="tablist"><slot name="tabs" /></div>
    <slot />
  </section>
</template>
