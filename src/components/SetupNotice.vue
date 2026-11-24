<script setup lang="ts">
import { isSupabaseConfigured } from '@/lib/supabase'
</script>

<template>
  <div v-if="!isSupabaseConfigured" class="bg-mango px-4 py-2 text-center text-xs text-ink">
    Supabase isn't connected yet. Copy <code>.env.example</code> to <code>.env.local</code>, add your project URL and anon key, then restart <code>npm run dev</code>.
  </div>
</template>
