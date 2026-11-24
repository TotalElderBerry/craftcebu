<script setup lang="ts">
import type { ApplicationInput } from '@/lib/seller'
import { ref } from 'vue'
import { toast } from 'vue-sonner'
import ShopProfileForm from '@/components/seller/ShopProfileForm.vue'
import { updateShop } from '@/lib/seller'
import { useSellerStore } from '@/stores/seller'

const seller = useSellerStore()
const saving = ref(false)

async function save(input: ApplicationInput) {
  if (!seller.shop) return
  saving.value = true
  try {
    // Sample photos were for the application review only; leave them as they are.
    const { sample_photos: _, ...profile } = input
    await updateShop(seller.shop.id, profile)
    await seller.load()
    toast.success('Shop profile saved.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save')
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl">
    <section class="rounded-lg border bg-card p-5 sm:p-6">
      <h1 class="text-lg font-semibold">Shop Profile</h1>
      <p class="mb-6 text-sm text-muted-foreground">
        This is what buyers see at the top of your shop page.
        <RouterLink v-if="seller.shop" :to="`/artisans/${seller.shop.slug}`" class="text-primary hover:underline">View it</RouterLink>
      </p>
      <div v-if="!seller.shop" class="h-80 animate-pulse rounded bg-muted" />
      <ShopProfileForm v-else :key="seller.shop.id" :initial="seller.shop" submit-label="Save profile" :saving="saving" @submit="save" />
    </section>
  </div>
</template>
