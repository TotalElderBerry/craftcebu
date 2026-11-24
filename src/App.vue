<script setup lang="ts">
import ConfirmHost from '@/components/ConfirmHost.vue'
import { Toaster } from '@/components/ui/sonner'
</script>

<template>
  <RouterView />
  <ConfirmHost />
  <!-- Offset below the notch / status bar in a WebView -->
  <Toaster rich-colors position="top-center" :offset="{ top: 'calc(env(safe-area-inset-top) + 16px)' }" :mobile-offset="{ top: 'calc(env(safe-area-inset-top) + 12px)' }" />
</template>
