<script setup lang="ts">
import { Button } from '@/components/ui/button'
</script>

<template>
  <div class="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
    <p class="font-display text-8xl text-primary italic">404</p>
    <h1 class="mt-4 font-display text-4xl font-medium">Wala diri ang imong gipangita</h1>
    <p class="mt-2 text-muted-foreground">The page you're looking for isn't here.</p>
    <Button class="mt-6" as-child><RouterLink to="/">Back home</RouterLink></Button>
  </div>
</template>
