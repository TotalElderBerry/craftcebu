<script setup lang="ts">
import { HeartIcon } from '@lucide/vue'
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'
import { useWishlistStore } from '@/stores/wishlist'

const props = withDefaults(defineProps<{ productId: string, productName: string, variant?: 'card' | 'page' }>(), { variant: 'card' })

const auth = useAuthStore()
const wishlist = useWishlistStore()
const router = useRouter()
const route = useRoute()
const saved = computed(() => wishlist.has(props.productId))

async function toggle() {
  if (!auth.user) {
    router.push({ name: 'login', query: { redirect: route.fullPath } })
    return
  }
  try {
    const nowSaved = await wishlist.toggle(props.productId)
    toast.success(nowSaved ? `Saved ${props.productName}` : 'Removed from your saved pieces', nowSaved ? { action: { label: 'View', onClick: () => router.push('/wishlist') } } : undefined)
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update your saved pieces')
  }
}
</script>

<template>
  <button
    type="button"
    :aria-pressed="saved"
    :aria-label="saved ? `Remove ${productName} from saved` : `Save ${productName}`"
    :class="cn(
      'grid place-items-center transition-colors',
      variant === 'card' ? 'size-10 rounded-full bg-background/90 shadow-sm hover:bg-background' : 'size-12 rounded-full border bg-card hover:border-primary',
    )"
    @click.prevent.stop="toggle"
  >
    <HeartIcon :class="cn(variant === 'card' ? 'size-4' : 'size-5', saved ? 'fill-primary text-primary' : 'text-foreground')" />
  </button>
</template>
